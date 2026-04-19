#!/usr/bin/env python3
"""
Filter 6502 execution traces by ROM tag so debugging focuses on a chosen ROM image.

Trace lines look like:
  H $9199`e : jmp  $ffc2   ...
  H $ffc2`o : jmp  $ea1e   ...

The letter after the address (here `e`, `o`) identifies which ROM that PC belongs to.
Lines whose ROM tag matches --rom are emitted verbatim.

Runs in other ROMs are collapsed: the first and last instruction line in each contiguous
non-matching run are kept; lines strictly between them are replaced by a single:

  ...

Other lines (headers, non-H trace lines) pass through. When they appear in the middle
of an external run, pending collapse is flushed first.
"""

from __future__ import annotations

import argparse
import io
import re
import signal
import sys
from typing import TextIO

# First ROM tag after "H $hex" on a standard instruction line.
RE_ROM_LINE = re.compile(r"^H\s+\$[0-9a-fA-F]+`([a-zA-Z])")


def rom_tag_from_line(line: str) -> str | None:
    m = RE_ROM_LINE.match(line)
    return m.group(1) if m else None


def filter_stream(inp: TextIO, out: TextIO, *, keep_rom: str) -> None:
    """
    Streaming filter: external runs are collapsed to first + optional ... + last.
    Lines strictly between first and last external (same run) are omitted; ellipsis is
    emitted only when at least one full line was omitted between first and last.
    """
    # Inside an external run after emitting the first line:
    # tail_count == 0: only the first line seen so far
    # tail_count == 1: two external lines (first emitted, one buffered as last)
    # tail_count >= 2: three+ external lines; ellipsis before emitting last
    in_external = False
    tail_count = 0
    last_external_line: str = ""

    def flush_external() -> None:
        nonlocal in_external, tail_count, last_external_line
        in_external = False
        tail_count = 0
        last_external_line = ""

    for line in inp:
        tag = rom_tag_from_line(line)

        if tag is None:
            if in_external:
                if tail_count == 1:
                    out.write(last_external_line)
                elif tail_count >= 2:
                    out.write("...\n")
                    out.write(last_external_line)
                flush_external()
            out.write(line)
            continue

        if tag == keep_rom:
            if in_external:
                if tail_count == 1:
                    out.write(last_external_line)
                elif tail_count >= 2:
                    out.write("...\n")
                    out.write(last_external_line)
                flush_external()
            out.write(line)
            continue

        # External (non-keep) ROM line.
        if not in_external:
            out.write(line)
            in_external = True
            tail_count = 0
            last_external_line = line
            continue

        # Still in external run.
        tail_count += 1
        last_external_line = line

    # EOF while still in external: emit tail like return to keep_rom
    if in_external:
        if tail_count == 1:
            out.write(last_external_line)
        elif tail_count >= 2:
            out.write("...\n")
            out.write(last_external_line)


def _open_text(path: str, mode: str) -> TextIO:
    return open(path, mode, encoding="utf-8", errors="replace", newline="")


def main(argv: list[str]) -> int:
    try:
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    except Exception:
        pass

    ap = argparse.ArgumentParser(
        description="Filter trace lines to one ROM tag; collapse other ROMs to first/.../last.",
    )
    ap.add_argument("input", help="Input trace file path, or '-' for stdin.")
    ap.add_argument(
        "-o",
        "--output",
        default="-",
        help="Output file path (default: '-', stdout).",
    )
    ap.add_argument(
        "--rom",
        default="e",
        metavar="TAG",
        help='ROM letter to keep (default: "%(default)s").',
    )

    ns = ap.parse_args(argv)
    keep_rom = ns.rom
    if len(keep_rom) != 1:
        ap.error("--rom must be a single character")

    if ns.input == "-":
        inp: TextIO = io.TextIOWrapper(
            sys.stdin.buffer, encoding="utf-8", errors="replace", newline=""
        )
    else:
        inp = _open_text(ns.input, "r")

    if ns.output == "-":
        out: TextIO = io.TextIOWrapper(
            sys.stdout.buffer, encoding="utf-8", errors="replace", newline=""
        )
    else:
        out = _open_text(ns.output, "w")

    try:
        try:
            filter_stream(inp, out, keep_rom=keep_rom)
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
