from __future__ import annotations

import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping

import yaml
from beebium.screen import dump_screen

from helpers import command


@dataclass(frozen=True)
class ScreenExpect:
    contains: tuple[str, ...] = ()
    regex: tuple[str, ...] = ()


@dataclass(frozen=True)
class ScreenCheck:
    expect: ScreenExpect


@dataclass(frozen=True)
class YamlStep:
    name: str
    paste: tuple[str, ...]
    delay_seconds: float | None
    checks: tuple[ScreenCheck, ...]


@dataclass(frozen=True)
class YamlSuite:
    path: Path
    group: str
    disk: str
    setup: tuple[str, ...]
    steps: tuple[YamlStep, ...]


def load_suite(path: Path, vars: Mapping[str, str] | None = None) -> YamlSuite:
    vars = vars or {}
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: top-level YAML value must be a mapping")

    disk = data.get("disk")
    if not isinstance(disk, str) or not disk.strip():
        raise ValueError(f"{path}: missing non-empty disk")

    setup = _string_list(data.get("paste"))
    raw_steps = data.get("steps")
    if not isinstance(raw_steps, list):
        raise ValueError(f"{path}: missing steps list")

    return YamlSuite(
        path=path,
        group=str(data.get("group") or ""),
        disk=_expand(disk.strip(), vars),
        setup=tuple(_expand(s, vars) for s in setup),
        steps=tuple(_parse_step(path, i, raw, vars) for i, raw in enumerate(raw_steps)),
    )


def run_suite(
    bbc,
    suite: YamlSuite,
    *,
    fhost: str,
    disk_slot: int = 7,
    drive: int = 0,
    paste_delay: float = 0.1,
    poll_interval: float = 0.05,
    evidence=None,
) -> None:
    if evidence is None:
        evidence = getattr(bbc, "_fn_screen_evidence", None)

    command(bbc, f"*FHOST {fhost}")
    time.sleep(paste_delay)
    command(bbc, f"*FIN {disk_slot} {suite.disk}")
    time.sleep(paste_delay)
    command(bbc, f"*FMOUNT {disk_slot} {drive}")
    time.sleep(paste_delay)

    for line in suite.setup:
        command(bbc, line)
        time.sleep(paste_delay)

    for step in suite.steps:
        for line in step.paste:
            command(bbc, line)
            time.sleep(paste_delay)

        if not step.checks:
            time.sleep(step.delay_seconds if step.delay_seconds is not None else 2.0)
            continue

        timeout = step.delay_seconds if step.delay_seconds is not None else 8.0
        for check in step.checks:
            _wait_for_screen(
                bbc,
                check.expect,
                label=f"{suite.path.name}:{step.name}",
                timeout=timeout,
                poll_interval=poll_interval,
                evidence=evidence,
            )


def _parse_step(
    path: Path,
    index: int,
    raw: Any,
    vars: Mapping[str, str],
) -> YamlStep:
    if not isinstance(raw, dict):
        raise ValueError(f"{path}: step {index} must be a mapping")
    name = raw.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValueError(f"{path}: step {index} missing non-empty name")

    checks = tuple(_parse_check(path, index, c, vars) for c in raw.get("checks") or ())
    delay = float(raw["delay_seconds"]) if "delay_seconds" in raw else None
    return YamlStep(
        name=name.strip(),
        paste=tuple(_expand(s, vars) for s in _string_list(raw.get("paste"))),
        delay_seconds=delay,
        checks=checks,
    )


def _parse_check(
    path: Path,
    step_index: int,
    raw: Any,
    vars: Mapping[str, str],
) -> ScreenCheck:
    if not isinstance(raw, dict) or set(raw.keys()) != {"screen"}:
        raise ValueError(f"{path}: step {step_index} only migrated screen checks are supported")
    body = raw["screen"]
    if not isinstance(body, dict):
        raise ValueError(f"{path}: step {step_index} screen check must be a mapping")
    expect = body.get("expect")
    if not isinstance(expect, dict):
        raise ValueError(f"{path}: step {step_index} screen check requires expect")
    return ScreenCheck(
        expect=ScreenExpect(
            contains=tuple(_expand(str(x), vars) for x in (expect.get("contains") or ())),
            regex=tuple(_expand(str(x), vars) for x in (expect.get("regex") or ())),
        )
    )


def _wait_for_screen(
    bbc,
    expect: ScreenExpect,
    *,
    label: str,
    timeout: float,
    poll_interval: float,
    evidence=None,
) -> None:
    deadline = time.monotonic() + max(timeout, 0.0)
    last_screen = ""
    last_failures: list[str] = []
    while True:
        last_screen = dump_screen(bbc)
        last_failures = _screen_failures(last_screen, expect)
        if not last_failures:
            if evidence is not None:
                evidence.capture(bbc, label, screen=last_screen)
            return
        if time.monotonic() >= deadline:
            if evidence is not None:
                evidence.capture(bbc, f"timeout {label}", screen=last_screen)
            failures = "\n".join(f"  - {f}" for f in last_failures)
            raise AssertionError(
                f"{label}: screen expectations not met within {timeout}s\n"
                f"{failures}\nSCREEN:\n{last_screen}"
            )
        time.sleep(poll_interval)


def _screen_failures(screen: str, expect: ScreenExpect) -> list[str]:
    failures: list[str] = []
    for text in expect.contains:
        if text not in screen:
            failures.append(f"missing substring {text!r}")
    for pattern in expect.regex:
        if re.search(pattern, screen) is None:
            failures.append(f"regex did not match {pattern!r}")
    return failures


def _string_list(raw: Any) -> tuple[str, ...]:
    if raw is None:
        return ()
    if isinstance(raw, str):
        return (raw,)
    if isinstance(raw, Iterable):
        return tuple(str(x) for x in raw)
    raise ValueError(f"expected string or list of strings, got {type(raw).__name__}")


def _expand(template: str, vars: Mapping[str, str]) -> str:
    out = template
    for key, value in vars.items():
        out = out.replace("{" + key + "}", value)
    return out
