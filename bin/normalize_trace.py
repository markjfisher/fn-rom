#!/usr/bin/env python3
"""
Normalize 6502 trace logs so "diff" focuses on meaningful changes.

Currently masks:
- S=xx (stack pointer) -> S=__
- P=...... (processor flags) -> keep only N,V,Z,C; mask D and I positions with '_'
Optionally:
- mask V in P=...... as well (use --mask-p-v)

Example:
  P=nvdIZC  -> P=nv__ZC
  P=NVdizC  -> P=NV__zC
"""

from __future__ import annotations

import argparse
import io
import re
import signal
import sys
from typing import TextIO


RE_S = re.compile(r"\bS=([0-9a-fA-F]{2})\b")
RE_P = re.compile(r"\bP=([^\s]{6})\b")
RE_STACK_EA = re.compile(r"\[\$01([0-9a-fA-F]{2})`m\]")


def normalize_p_flags(flags: str, *, mask_v: bool) -> str:
    # Expected order in these traces: N V D I Z C (6 chars, case indicates set/clear).
    # User wants to compare only nVzC, ignoring D and I.
    if len(flags) != 6:
        return flags
    out = list(flags)
    if mask_v:
        out[1] = "_"
    out[2] = "_"
    out[3] = "_"
    return "".join(out)


def normalize_line(line: str, *, mask_s: bool, mask_p_di: bool, mask_p_v: bool) -> str:
    if mask_s:
        line = RE_S.sub("S=__", line)
        line = RE_STACK_EA.sub("[$01__`m]", line)

    if mask_p_di:
        def _p_sub(m: re.Match[str]) -> str:
            return "P=" + normalize_p_flags(m.group(1), mask_v=mask_p_v)

        line = RE_P.sub(_p_sub, line)

    return line


def normalize_stream(inp: TextIO, out: TextIO, *, mask_s: bool, mask_p_di: bool, mask_p_v: bool) -> None:
    for line in inp:
        out.write(normalize_line(line, mask_s=mask_s, mask_p_di=mask_p_di, mask_p_v=mask_p_v))


def _open_text(path: str, mode: str) -> TextIO:
    return open(path, mode, encoding="utf-8", errors="replace", newline="")


def main(argv: list[str]) -> int:
    # Make piping to tools like `head` not throw noisy stacktraces.
    try:
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    except Exception:
        pass

    ap = argparse.ArgumentParser(
        description="Normalize 6502 trace logs for easier diffing.",
    )
    ap.add_argument("input", help="Input trace file path, or '-' for stdin.")
    ap.add_argument(
        "-o",
        "--output",
        default="-",
        help="Output file path (default: '-', stdout).",
    )
    ap.add_argument(
        "--no-mask-s",
        action="store_true",
        help="Do not mask stack pointer S=..",
    )
    ap.add_argument(
        "--no-mask-p-di",
        action="store_true",
        help="Do not mask D/I bits in P=......",
    )
    ap.add_argument(
        "--mask-p-v",
        action="store_true",
        help="Also mask V in P=...... (overflow flag).",
    )

    ns = ap.parse_args(argv)
    mask_s = not ns.no_mask_s
    mask_p_di = not ns.no_mask_p_di
    mask_p_v = bool(ns.mask_p_v)

    if ns.input == "-":
        inp: TextIO = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace", newline="")
    else:
        inp = _open_text(ns.input, "r")

    if ns.output == "-":
        out: TextIO = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace", newline="")
    else:
        out = _open_text(ns.output, "w")

    try:
        try:
            normalize_stream(inp, out, mask_s=mask_s, mask_p_di=mask_p_di, mask_p_v=mask_p_v)
        except BrokenPipeError:
            return 0
    finally:
        if inp is not sys.stdin and hasattr(inp, "close"):
            inp.close()
        if out is not sys.stdout and hasattr(out, "close"):
            try:
                out.close()
            except BrokenPipeError:
                pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

