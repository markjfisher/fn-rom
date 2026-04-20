#!/usr/bin/env python3
"""
Run BASIC programs inside b2 via bin/b2-http.py: paste commands, then optional
checks (screen text, peek memory vs expected bytes). Steps are YAML.

Example:
  pip install -r integration-tests/requirements.txt   # PyYAML
  ./integration_test.py --fhost-path 'tnfs://192.168.1.101/bbc/' \\
    --disk /path/to/test-disk.ssd \\
    --steps-dir ../integration-tests/steps

Paste lines and paths may use placeholders: {FHOST_PATH}, {DISK}

**delay_seconds** (per step):

- Step has **screen** checks: maximum time to poll the screen every ``--screen-poll-interval``
  seconds until expectations pass (fast exit on success). Not a fixed pause before the first grab.
- Step has **peek-only** checks (no screen): ignored — peek runs immediately after paste.
- Step has **no checks**: fixed settle time after paste (same as before).

Peek checks always run once, right after the preceding screen check succeeds (no extra wait).

PyYAML is only required when using --steps / --steps-dir (pip install -r integration-tests/requirements.txt).
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence, Union

def _yaml_module():
    """Lazy import so built-in-only runs work without PyYAML installed."""
    try:
        return importlib.import_module("yaml")
    except ImportError as e:
        raise SystemExit(
            "Missing dependency: PyYAML (needed for --steps / --steps-dir)\n"
            "Install with:\n"
            "  python -m pip install PyYAML\n"
            "or: pip install -r integration-tests/requirements.txt\n"
        ) from e


@dataclass(frozen=True)
class ScreenExpect:
    """Assertions on text from b2-http.py screen (full buffer as one string)."""

    contains: tuple[str, ...] = ()
    regex: tuple[str, ...] = ()


@dataclass(frozen=True)
class ScreenStepCheck:
    """Run b2-http screen with optional parameter overrides, then assert on text."""

    expect: ScreenExpect
    start: str | None = None
    wrap_adjustment: str | None = None
    screen_size: int | None = None
    lines: int | None = None
    chars_per_line: int | None = None
    stride: int | None = None


@dataclass(frozen=True)
class PeekStepCheck:
    """b2-http peek BEGIN END; compare raw bytes to a file, hex string, or SHA-256."""

    begin: str
    end: str
    s: str | None = None
    mos: bool | None = None
    expect_file: Path | None = None
    expect_hex: str | None = None
    expect_sha256: str | None = None


StepCheck = Union[ScreenStepCheck, PeekStepCheck]


@dataclass(frozen=True)
class IntegrationCase:
    """Paste lines, then checks. delay_seconds meaning depends on checks (see module docstring)."""

    name: str
    paste_lines: tuple[str, ...]
    delay_seconds: float | None = None
    checks: tuple[StepCheck, ...] = ()
    group: str = ""
    source_file: str = ""
    step_dir: Path = field(default_factory=lambda: Path("."))


def _repo_bin() -> Path:
    return Path(__file__).resolve().parent


def _expand_placeholders(template: str, vars: Mapping[str, str]) -> str:
    out = template
    for k, v in vars.items():
        out = out.replace("{" + k + "}", v)
    return out


def _default_step_vars(args: argparse.Namespace) -> dict[str, str]:
    return {
        "FHOST_PATH": args.fhost_path,
        "DISK": args.disk,
    }


def _resolve_expect_file(chk_path: Path, step_dir: Path, vars: Mapping[str, str]) -> Path:
    """expect_file paths are relative to the YAML file's directory."""
    expanded = _expand_placeholders(str(chk_path), vars)
    p = Path(expanded)
    if p.is_absolute():
        return p.resolve()
    return (step_dir / p).resolve()


class B2HttpCli:
    """Thin wrapper around b2-http.py."""

    def __init__(
        self,
        b2_http: Path,
        *,
        host: str = "localhost",
        port: int = 48075,
        win: str = "*",
    ) -> None:
        self._exe = b2_http
        self._host = host
        self._port = port
        self._win = win

    def _base(self) -> list[str]:
        return [
            str(self._exe),
            "--host",
            self._host,
            "--port",
            str(self._port),
            "--win",
            self._win,
        ]

    def paste(self, text: str, *, check: bool = True) -> None:
        cmd = self._base() + ["paste", "-t", text]
        self._run(cmd, check=check)

    def screen_text(
        self,
        *,
        start: str = "7c00",
        wrap_adjustment: str = "5000",
        screen_size: int = 1024,
        lines: int = 25,
        chars_per_line: int = 40,
        stride: int = 40,
    ) -> str:
        cmd = self._base() + [
            "screen",
            "--start",
            start,
            "--wrap-adjustment",
            wrap_adjustment,
            "--screen-size",
            str(screen_size),
            "--lines",
            str(lines),
            "--chars",
            str(chars_per_line),
            "--stride",
            str(stride),
        ]
        out = self._run_capture(cmd)
        return out.decode("utf-8", errors="replace")

    def peek_bytes(
        self,
        begin: str,
        end: str,
        *,
        s: str | None = None,
        mos: bool | None = None,
    ) -> bytes:
        cmd = self._base() + ["peek", begin, end]
        if s is not None:
            cmd.extend(["-s", s])
        if mos is not None:
            cmd.extend(["--mos", "true" if mos else "false"])
        return self._run_capture(cmd)

    def reset(self, *, boot: bool = False, config: str | None = None) -> None:
        cmd = self._base() + ["reset"]
        if boot:
            cmd.append("--boot")
        if config:
            cmd.extend(["--config", config])
        self._run(cmd)

    def _run(self, cmd: Sequence[str], *, check: bool = True) -> None:
        r = subprocess.run(cmd, capture_output=True)
        if check and r.returncode != 0:
            err = r.stderr.decode("utf-8", errors="replace") or r.stdout.decode(
                "utf-8", errors="replace"
            )
            raise RuntimeError(
                f"Command failed ({r.returncode}): {' '.join(cmd)}\n{err}"
            )

    def _run_capture(self, cmd: Sequence[str]) -> bytes:
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode != 0:
            err = r.stderr.decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Command failed ({r.returncode}): {' '.join(cmd)}\n{err}"
            )
        return r.stdout


def run_global_setup(
    b2: B2HttpCli,
    *,
    fhost_path: str,
    disk_path: str,
    delay: float,
) -> None:
    """*FHOST, *FIN, *FMOUNT — same sequence as b2-scripts/tnfs.txt style FHOST."""
    b2.paste(f"*FHOST {fhost_path}")
    time.sleep(delay)
    b2.paste(f"*FIN {disk_path}")
    time.sleep(delay)
    b2.paste("*FMOUNT 0 0")
    time.sleep(delay)


def assert_screen(screen: str, expect: ScreenExpect, *, label: str) -> list[str]:
    failures: list[str] = []
    for s in expect.contains:
        if s not in screen:
            failures.append(f"[{label}] missing substring: {s!r}")
    for pattern in expect.regex:
        if not re.search(pattern, screen):
            failures.append(f"[{label}] regex did not match: {pattern!r}")
    return failures


def _hex_nibbles_to_bytes(text: str) -> bytes:
    pairs = re.findall(r"[0-9A-Fa-f]{2}", text)
    return bytes(int(p, 16) for p in pairs)


def _peek_expected_bytes(chk: PeekStepCheck, step_dir: Path, vars: Mapping[str, str]) -> bytes:
    n_expects = sum(
        1
        for x in (chk.expect_file, chk.expect_hex, chk.expect_sha256)
        if x is not None
    )
    if n_expects != 1:
        raise ValueError(
            "peek check requires exactly one of: expect_file, expect_hex, expect_sha256"
        )
    if chk.expect_file is not None:
        path = _resolve_expect_file(chk.expect_file, step_dir, vars)
        return path.read_bytes()
    if chk.expect_hex is not None:
        expanded = _expand_placeholders(chk.expect_hex, vars)
        return _hex_nibbles_to_bytes(expanded)
    # sha256: compare in assert — return placeholder? Use empty and handle in assert
    return b""


def assert_peek(
    got: bytes,
    chk: PeekStepCheck,
    *,
    label: str,
    step_dir: Path,
    vars: Mapping[str, str],
) -> list[str]:
    if chk.expect_sha256 is not None:
        want_hex = _expand_placeholders(chk.expect_sha256.strip(), vars).lower()
        got_hash = hashlib.sha256(got).hexdigest()
        if got_hash != want_hex:
            return [
                f"[{label}] peek SHA-256 mismatch: got {got_hash} expected {want_hex}"
            ]
        return []

    expected = _peek_expected_bytes(chk, step_dir, vars)
    if len(got) != len(expected):
        return [
            f"[{label}] peek length {len(got)} != expected {len(expected)} "
            f"(begin={chk.begin} end={chk.end})"
        ]
    for i, (a, b) in enumerate(zip(got, expected)):
        if a != b:
            snippet_got = got[max(0, i - 4) : i + 8].hex()
            snippet_exp = expected[max(0, i - 4) : i + 8].hex()
            return [
                f"[{label}] peek mismatch at offset {i}: "
                f"got 0x{a:02x} expected 0x{b:02x}; "
                f"context got={snippet_got} exp={snippet_exp}"
            ]
    return []


def _step_has_screen(case: IntegrationCase) -> bool:
    return any(isinstance(c, ScreenStepCheck) for c in case.checks)


def _poll_screen_until_pass(
    b2: B2HttpCli,
    check: ScreenStepCheck,
    base_sk: dict[str, Any],
    *,
    label: str,
    timeout_s: float,
    poll_interval: float,
    verbose: bool,
) -> list[str]:
    """Poll screen until expectations pass or timeout (first match wins)."""
    sk = _merge_screen_kwargs(base_sk, check)
    deadline = time.monotonic() + max(timeout_s, 0.0)
    interval = max(poll_interval, 0.0)
    attempt = 0
    last_screen = ""
    last_failures: list[str] = []

    while True:
        attempt += 1
        last_screen = b2.screen_text(**sk)
        last_failures = assert_screen(last_screen, check.expect, label=label)
        if not last_failures:
            if verbose:
                print(f"--- screen ok ({label}) after {attempt} grab(s)", file=sys.stderr)
                print(last_screen, file=sys.stderr)
            return []
        if time.monotonic() >= deadline:
            out = [
                f"[{label}] screen timed out after {timeout_s}s "
                f"({attempt} grabs, poll every {interval}s)",
            ]
            out.extend(last_failures)
            out.append(f"[{label}] last screen capture:\n{last_screen}")
            return out
        if verbose:
            print(
                f"--- screen poll attempt {attempt} ({label}) "
                f"({len(last_failures)} assertion(s) failed), retry…",
                file=sys.stderr,
            )
            print(last_screen, file=sys.stderr)
        if interval:
            time.sleep(interval)


def _merge_screen_kwargs(
    base: dict[str, Any], chk: ScreenStepCheck
) -> dict[str, Any]:
    out = dict(base)
    if chk.start is not None:
        out["start"] = chk.start
    if chk.wrap_adjustment is not None:
        out["wrap_adjustment"] = chk.wrap_adjustment
    if chk.screen_size is not None:
        out["screen_size"] = chk.screen_size
    if chk.lines is not None:
        out["lines"] = chk.lines
    if chk.chars_per_line is not None:
        out["chars_per_line"] = chk.chars_per_line
    if chk.stride is not None:
        out["stride"] = chk.stride
    return out


def run_case(
    b2: B2HttpCli,
    case: IntegrationCase,
    *,
    screen_kwargs: dict[str, Any],
    vars: Mapping[str, str],
    verbose: bool,
    default_screen_timeout: float,
    screen_poll_interval: float,
) -> list[str]:
    if verbose:
        if case.group:
            print(
                f"--- {case.group} — {case.name} ({case.source_file})",
                file=sys.stderr,
            )
        else:
            print(f"--- case: {case.name}", file=sys.stderr)

    paste_delay = screen_kwargs.get("paste_delay", 0.3)
    for line in case.paste_lines:
        b2.paste(line)
        time.sleep(paste_delay)

    base_sk = {
        k: v
        for k, v in screen_kwargs.items()
        if k != "paste_delay"
    }

    failures: list[str] = []

    if not case.checks:
        settle = case.delay_seconds if case.delay_seconds is not None else 2.0
        if settle > 0:
            time.sleep(settle)
        return []

    has_screen = _step_has_screen(case)
    screen_timeout = (
        case.delay_seconds
        if case.delay_seconds is not None
        else default_screen_timeout
    )
    if has_screen:
        screen_timeout = max(screen_timeout, 0.0)

    for i, check in enumerate(case.checks):
        sub = f"{case.name}/check[{i}]"
        if isinstance(check, ScreenStepCheck):
            failures.extend(
                _poll_screen_until_pass(
                    b2,
                    check,
                    base_sk,
                    label=sub,
                    timeout_s=screen_timeout,
                    poll_interval=screen_poll_interval,
                    verbose=verbose,
                )
            )
            if failures:
                return failures
        elif isinstance(check, PeekStepCheck):
            got = b2.peek_bytes(
                check.begin,
                check.end,
                s=check.s,
                mos=check.mos,
            )
            if verbose:
                print(
                    f"--- peek {check.begin}..{check.end} ({len(got)} bytes) ({sub})",
                    file=sys.stderr,
                )
                print(got.hex(), file=sys.stderr)
            failures.extend(
                assert_peek(
                    got,
                    check,
                    label=sub,
                    step_dir=case.step_dir,
                    vars=vars,
                )
            )
            if failures:
                return failures
    return failures


def _load_yaml_file(path: Path) -> dict[str, Any]:
    yaml = _yaml_module()
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: top-level must be a mapping (dict)")
    return data


def _parse_expect_block(raw: Any) -> ScreenExpect:
    if raw is None:
        return ScreenExpect()
    if not isinstance(raw, dict):
        raise ValueError("'expect' must be a mapping with 'contains' and/or 'regex' lists")
    contains = raw.get("contains") or []
    regex = raw.get("regex") or []
    if not isinstance(contains, list):
        raise ValueError("expect.contains must be a list")
    if not isinstance(regex, list):
        raise ValueError("expect.regex must be a list")
    return ScreenExpect(
        contains=tuple(str(x) for x in contains),
        regex=tuple(str(x) for x in regex),
    )


def _screen_check_from_mapping(m: dict[str, Any], vars: Mapping[str, str]) -> ScreenStepCheck:
    exp_raw = m.get("expect")
    if exp_raw is None:
        raise ValueError("screen check must include 'expect'")
    exp = _parse_expect_block(exp_raw)
    exp = ScreenExpect(
        contains=tuple(_expand_placeholders(s, vars) for s in exp.contains),
        regex=tuple(_expand_placeholders(s, vars) for s in exp.regex),
    )

    def opt_str(key: str) -> str | None:
        v = m.get(key)
        if v is None:
            return None
        return _expand_placeholders(str(v), vars)

    def opt_int(key: str) -> int | None:
        v = m.get(key)
        if v is None:
            return None
        return int(v)

    return ScreenStepCheck(
        expect=exp,
        start=opt_str("start"),
        wrap_adjustment=opt_str("wrap_adjustment"),
        screen_size=opt_int("screen_size"),
        lines=opt_int("lines"),
        chars_per_line=opt_int("chars_per_line"),
        stride=opt_int("stride"),
    )


def _peek_check_from_mapping(m: dict[str, Any], vars: Mapping[str, str]) -> PeekStepCheck:
    begin = m.get("begin")
    end = m.get("end")
    if not isinstance(begin, str) or not str(begin).strip():
        raise ValueError("peek.begin must be a non-empty string")
    if not isinstance(end, str) or not str(end).strip():
        raise ValueError("peek.end must be a non-empty string")

    s = m.get("s")
    mos = m.get("mos")
    mos_b: bool | None
    if mos is None:
        mos_b = None
    elif isinstance(mos, bool):
        mos_b = mos
    else:
        mos_b = str(mos).lower() in ("1", "true", "yes")

    ef = m.get("expect_file")
    eh = m.get("expect_hex")
    es = m.get("expect_sha256")
    # paths may contain placeholders
    expect_path: Path | None = None
    if ef is not None:
        expect_path = Path(_expand_placeholders(str(ef), vars))
    expect_hex_str: str | None = None
    if eh is not None:
        expect_hex_str = str(eh)
    expect_sha: str | None = None
    if es is not None:
        expect_sha = _expand_placeholders(str(es).strip(), vars)

    return PeekStepCheck(
        begin=_expand_placeholders(str(begin).strip(), vars),
        end=_expand_placeholders(str(end).strip(), vars),
        s=_expand_placeholders(str(s), vars) if s is not None else None,
        mos=mos_b,
        expect_file=expect_path,
        expect_hex=expect_hex_str,
        expect_sha256=expect_sha,
    )


def _parse_checks_list(
    raw_checks: list[Any],
    *,
    path: Path,
    step_index: int,
    vars: Mapping[str, str],
) -> tuple[StepCheck, ...]:
    out: list[StepCheck] = []
    for j, raw in enumerate(raw_checks):
        if not isinstance(raw, dict) or len(raw) != 1:
            raise ValueError(
                f"{path}: step {step_index} checks[{j}] must be a single-key mapping "
                "(e.g. screen: {{...}} or peek: {{...}})"
            )
        kind = next(iter(raw.keys()))
        body = raw[kind]
        if not isinstance(body, dict):
            raise ValueError(f"{path}: step {step_index} checks[{j}].{kind} must be a mapping")
        if kind == "screen":
            out.append(_screen_check_from_mapping(body, vars))
        elif kind == "peek":
            out.append(_peek_check_from_mapping(body, vars))
        else:
            raise ValueError(
                f"{path}: step {step_index} checks[{j}] unknown kind {kind!r} "
                "(use 'screen' or 'peek')"
            )
    return tuple(out)


def _parse_step_item(
    item: dict[str, Any],
    *,
    path: Path,
    index: int,
    group: str,
    vars: Mapping[str, str],
) -> IntegrationCase:
    name = item.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValueError(f"{path}: step {index} missing/invalid 'name'")

    step_dir = path.parent.resolve()

    raw_paste = item.get("paste")
    if raw_paste is None:
        paste_lines = ()
    elif isinstance(raw_paste, str):
        paste_lines = (_expand_placeholders(raw_paste, vars),)
    elif isinstance(raw_paste, list):
        paste_lines = tuple(_expand_placeholders(str(x), vars) for x in raw_paste)
    else:
        raise ValueError(f"{path}: step {index} 'paste' must be a string or list")

    raw_checks = item.get("checks")
    has_legacy_expect = "expect" in item
    legacy_expect = item.get("expect")

    if has_legacy_expect and raw_checks is not None:
        raise ValueError(
            f"{path}: step {index} uses both 'expect' and 'checks'; use only 'checks'"
        )

    checks_list: list[StepCheck] = []

    if raw_checks is not None:
        if not isinstance(raw_checks, list):
            raise ValueError(f"{path}: step {index} 'checks' must be a list")
        checks_list.extend(_parse_checks_list(raw_checks, path=path, step_index=index, vars=vars))
    elif has_legacy_expect:
        exp = _parse_expect_block(legacy_expect)
        exp = ScreenExpect(
            contains=tuple(_expand_placeholders(s, vars) for s in exp.contains),
            regex=tuple(_expand_placeholders(s, vars) for s in exp.regex),
        )
        if exp.contains or exp.regex:
            checks_list.append(ScreenStepCheck(expect=exp))

    has_screen = any(isinstance(c, ScreenStepCheck) for c in checks_list)

    if "delay_seconds" in item:
        delay_seconds: float | None = float(item["delay_seconds"])
    elif has_screen:
        delay_seconds = None
    elif not checks_list:
        delay_seconds = 2.0
    else:
        # Peek-only (or other non-screen checks later): polling delay not used.
        delay_seconds = None

    return IntegrationCase(
        name=name.strip(),
        paste_lines=paste_lines,
        delay_seconds=delay_seconds,
        checks=tuple(checks_list),
        group=group,
        source_file=path.name,
        step_dir=step_dir,
    )


def _cases_from_yaml_file(path: Path, vars: Mapping[str, str]) -> list[IntegrationCase]:
    doc = _load_yaml_file(path)
    group = doc.get("group")
    if group is None:
        group = ""
    if not isinstance(group, str):
        raise ValueError(f"{path}: 'group' must be a string")

    raw_steps = doc.get("steps")
    if raw_steps is None:
        raw_steps = doc.get("cases")
    if not isinstance(raw_steps, list):
        raise ValueError(f"{path}: missing 'steps' (or alias 'cases') list")

    out: list[IntegrationCase] = []
    for i, raw in enumerate(raw_steps):
        if not isinstance(raw, dict):
            raise ValueError(f"{path}: step {i} must be a mapping (dict)")
        out.append(_parse_step_item(raw, path=path, index=i, group=group.strip(), vars=vars))
    return out


def _discover_yaml_files(steps_dir: Path) -> list[Path]:
    if not steps_dir.is_dir():
        raise SystemExit(f"Steps directory not found: {steps_dir}")
    files = sorted(
        p for p in steps_dir.iterdir() if p.is_file() and p.suffix in (".yaml", ".yml")
    )
    if not files:
        raise SystemExit(f"No .yaml/.yml files under: {steps_dir}")
    return files


def _cases_from_steps_dir(steps_dir: Path, vars: Mapping[str, str]) -> list[IntegrationCase]:
    cases: list[IntegrationCase] = []
    for path in _discover_yaml_files(steps_dir):
        cases.extend(_cases_from_yaml_file(path, vars))
    return cases


def default_osfile_cases() -> list[IntegrationCase]:
    return [
        IntegrationCase(
            name="osf01",
            paste_lines=('CHAIN "OSF01"',),
            delay_seconds=30.0,
            checks=(
                ScreenStepCheck(
                    expect=ScreenExpect(
                        contains=("$.Myself",),
                        regex=(
                            r"\$\.Myself\s+001DC5\s+001DE0\s+000027\s+026",
                        ),
                    ),
                ),
            ),
        ),
    ]


def select_cases(
    all_cases: Iterable[IntegrationCase], only: Sequence[str] | None
) -> list[IntegrationCase]:
    cases = list(all_cases)
    if not only:
        return cases
    want = set(only)
    picked = [c for c in cases if c.name in want]
    missing = want - {c.name for c in picked}
    if missing:
        raise SystemExit(f"Unknown case name(s): {sorted(missing)}")
    return picked


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Integration tests for b2 via b2-http.py (YAML steps; screen / peek)",
    )
    parser.add_argument(
        "--fhost-path",
        required=True,
        help="Argument for *FHOST (e.g. tnfs://host/share/ as in b2-scripts/tnfs.txt)",
    )
    parser.add_argument(
        "--disk",
        required=True,
        type=str,
        help="Path passed to *FIN (e.g. test-disk.ssd on the host)",
    )
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=48075)
    parser.add_argument("--win", default="*")
    parser.add_argument(
        "--b2-http",
        type=Path,
        default=None,
        help="Path to b2-http.py (default: ./b2-http.py next to this script)",
    )
    parser.add_argument(
        "--setup-delay",
        type=float,
        default=1.0,
        help="Seconds to wait after each global setup paste (default 1.0)",
    )
    parser.add_argument(
        "--steps",
        type=Path,
        default=None,
        help="Single YAML file with 'group' and 'steps' (fujinet-nio style)",
    )
    parser.add_argument(
        "--steps-dir",
        type=Path,
        default=None,
        help="Directory of *.yaml / *.yml (sorted by filename); all steps are concatenated",
    )
    parser.add_argument(
        "--no-builtin",
        action="store_true",
        help="Do not use built-in cases when no steps file/dir is given (exit with error)",
    )
    parser.add_argument(
        "--cases",
        nargs="*",
        default=None,
        metavar="NAME",
        help="Run only these step names (default: all)",
    )
    parser.add_argument(
        "--reset-first",
        action="store_true",
        help="Call b2-http reset before global setup",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        help="Print group, step name, captured screen text, and peek hex to stderr",
        action="store_true",
    )
    parser.add_argument("--screen-start", default="7c00")
    parser.add_argument("--wrap-adjustment", default="5000")
    parser.add_argument("--screen-size", type=int, default=1024)
    parser.add_argument("--screen-lines", type=int, default=25)
    parser.add_argument("--chars-per-line", type=int, default=40)
    parser.add_argument("--stride", type=int, default=40)
    parser.add_argument(
        "--paste-delay",
        type=float,
        default=0.3,
        help="Sleep after each paste line within a case",
    )
    parser.add_argument(
        "--screen-timeout-default",
        type=float,
        default=30.0,
        help=(
            "When a step has screen checks but omits delay_seconds, max seconds "
            "to poll the screen (default 30)"
        ),
    )
    parser.add_argument(
        "--screen-poll-interval",
        type=float,
        default=0.1,
        help="Seconds between screen grabs while waiting for expectations (default 0.1)",
    )

    args = parser.parse_args()

    if args.steps is not None and args.steps_dir is not None:
        raise SystemExit("Use either --steps or --steps-dir, not both")

    b2_http = args.b2_http if args.b2_http else _repo_bin() / "b2-http.py"
    if not b2_http.is_file():
        raise SystemExit(f"b2-http.py not found at {b2_http}")

    vars = _default_step_vars(args)

    if args.steps is not None:
        cases = _cases_from_yaml_file(args.steps, vars)
    elif args.steps_dir is not None:
        cases = _cases_from_steps_dir(args.steps_dir, vars)
    elif args.no_builtin:
        raise SystemExit(
            "No steps: pass --steps or --steps-dir, or omit --no-builtin for built-in cases"
        )
    else:
        cases = default_osfile_cases()

    cases = select_cases(cases, args.cases)

    screen_kwargs: dict[str, Any] = {
        "start": args.screen_start,
        "wrap_adjustment": args.wrap_adjustment,
        "screen_size": args.screen_size,
        "lines": args.screen_lines,
        "chars_per_line": args.chars_per_line,
        "stride": args.stride,
        "paste_delay": args.paste_delay,
    }

    b2 = B2HttpCli(b2_http, host=args.host, port=args.port, win=args.win)

    if args.reset_first:
        b2.reset()

    run_global_setup(
        b2,
        fhost_path=args.fhost_path,
        disk_path=args.disk,
        delay=args.setup_delay,
    )

    all_failures: list[str] = []
    for c in cases:
        all_failures.extend(
            run_case(
                b2,
                c,
                screen_kwargs=screen_kwargs,
                vars=vars,
                verbose=args.verbose,
                default_screen_timeout=args.screen_timeout_default,
                screen_poll_interval=args.screen_poll_interval,
            )
        )

    if all_failures:
        for m in all_failures:
            print(m, file=sys.stderr)
        raise SystemExit(1)
    print(f"OK: {len(cases)} case(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
