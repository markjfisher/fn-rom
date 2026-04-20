#!/usr/bin/env python3
"""
Run BASIC programs inside b2 via bin/b2-http.py: paste commands, capture screen,
and assert on the text. Steps are YAML (same idea as fujinet-nio integration-tests).

Example:
  pip install -r integration-tests/requirements.txt   # PyYAML
  ./integration_test.py --fhost-path 'tnfs://192.168.1.101/bbc/' \\
    --disk /path/to/test-disk.ssd \\
    --steps-dir ../integration-tests/steps

YAML step file (see integration-tests/steps/01_osfile.yaml):

    group: BBC / FS / OSFILE
    steps:
      - name: osf01
        paste:
          - 'CHAIN "OSF01"'
        delay_seconds: 3.0
        expect:
          contains:
            - "$.Myself"
          regex:
            - '\\$\\.Myself\\s+001DC5\\s+001DE0\\s+000027\\s+026'

Paste lines and expect strings may use placeholders: {FHOST_PATH}, {DISK}

PyYAML is only required when using --steps / --steps-dir (pip install -r integration-tests/requirements.txt).
"""

from __future__ import annotations

import argparse
import importlib
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


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
class IntegrationCase:
    """One test: paste one or more lines (each submitted with CR), wait, check screen."""

    name: str
    paste_lines: tuple[str, ...]
    delay_seconds: float = 2.0
    expect: ScreenExpect = field(default_factory=ScreenExpect)
    group: str = ""
    source_file: str = ""


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


class B2HttpCli:
    """Thin wrapper around b2-http.py (same defaults as typical FN + mode-7-style screen)."""

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


def assert_screen(screen: str, expect: ScreenExpect, *, case_name: str) -> list[str]:
    """Return list of failure messages (empty if all pass)."""
    failures: list[str] = []
    for s in expect.contains:
        if s not in screen:
            failures.append(f"[{case_name}] missing substring: {s!r}")
    for pattern in expect.regex:
        if not re.search(pattern, screen):
            failures.append(f"[{case_name}] regex did not match: {pattern!r}")
    return failures


def run_case(
    b2: B2HttpCli,
    case: IntegrationCase,
    *,
    screen_kwargs: dict[str, Any],
    verbose: bool,
) -> list[str]:
    if verbose:
        if case.group:
            print(
                f"--- {case.group} — {case.name} ({case.source_file})",
                file=sys.stderr,
            )
        else:
            print(f"--- case: {case.name}", file=sys.stderr)
    for line in case.paste_lines:
        b2.paste(line)
        time.sleep(screen_kwargs.get("paste_delay", 0.3))
    delay = max(case.delay_seconds, 0.0)
    if delay:
        time.sleep(delay)
    screen = b2.screen_text(**{k: v for k, v in screen_kwargs.items() if k != "paste_delay"})
    if verbose:
        print(screen, file=sys.stderr)
    return assert_screen(screen, case.expect, case_name=case.name)


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

    paste = item.get("paste")
    if paste is None:
        raise ValueError(f"{path}: step {index} missing 'paste'")
    if isinstance(paste, str):
        paste_lines = (_expand_placeholders(paste, vars),)
    elif isinstance(paste, list) and paste:
        paste_lines = tuple(_expand_placeholders(str(x), vars) for x in paste)
    else:
        raise ValueError(f"{path}: step {index} 'paste' must be a non-empty string or list")

    delay_seconds = float(item.get("delay_seconds", 2.0))
    expect = _parse_expect_block(item.get("expect"))
    expect = ScreenExpect(
        contains=tuple(_expand_placeholders(s, vars) for s in expect.contains),
        regex=tuple(_expand_placeholders(s, vars) for s in expect.regex),
    )

    return IntegrationCase(
        name=name.strip(),
        paste_lines=paste_lines,
        delay_seconds=delay_seconds,
        expect=expect,
        group=group,
        source_file=path.name,
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
    """
    Built-in checks when no --steps / --steps-dir is given.
    Same expectations as integration-tests/steps/01_osfile.yaml.
    """
    return [
        IntegrationCase(
            name="osf01",
            paste_lines=('CHAIN "OSF01"',),
            delay_seconds=3.0,
            expect=ScreenExpect(
                contains=("$.Myself",),
                regex=(
                    r"\$\.Myself\s+001DC5\s+001DE0\s+000027\s+026",
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
        description="Integration tests for b2 via b2-http.py (YAML steps + screen asserts)",
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
        action="store_true",
        help="Print group, step name, and captured screen text to stderr",
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
        all_failures.extend(run_case(b2, c, screen_kwargs=screen_kwargs, verbose=args.verbose))

    if all_failures:
        for m in all_failures:
            print(m, file=sys.stderr)
        raise SystemExit(1)
    print(f"OK: {len(cases)} case(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
