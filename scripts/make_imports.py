#!/usr/bin/env python3
"""
Run `make`, collect ca65 undefined-symbol errors, and print sorted `.import` /
`.importzp` lines grouped by source file.

Zero-page symbols are determined by `.exportzp` in `src/os.s`.

Per file, output order is: (1) aws_tmp / pws_tmp / cws_tmp scratch ZP names,
(2) other ZP symbols from os.s, (3) normal imports — each group sorted; blank
lines separate groups when both sides are non-empty.
"""

from __future__ import annotations

import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

from import_layout import UNDEF_RE, layout_import_lines, normalize_smart_quotes, parse_exportzp_symbols

REPO_ROOT = Path(__file__).resolve().parent.parent
OS_S = REPO_ROOT / "src" / "os.s"


def collect_undefined_by_file(make_output: str) -> OrderedDict[str, list[str]]:
    """First occurrence order of files; symbols per file in first-seen order, then deduped."""
    by_file: OrderedDict[str, dict[str, None]] = OrderedDict()
    for raw in make_output.splitlines():
        line = normalize_smart_quotes(raw)
        m = UNDEF_RE.match(line)
        if not m:
            continue
        path, sym = m.group(1), m.group(2)
        if path not in by_file:
            by_file[path] = {}
        if sym not in by_file[path]:
            by_file[path][sym] = None
    return OrderedDict((f, list(syms)) for f, syms in by_file.items())


def main() -> int:
    zp = parse_exportzp_symbols(OS_S)
    proc = subprocess.run(
        ["make"],
        cwd=str(REPO_ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    combined = proc.stdout or ""
    by_file = collect_undefined_by_file(combined)

    blocks: list[str] = []
    for fpath, syms in by_file.items():
        lines = [f"; {fpath}", *layout_import_lines(syms, zp)]
        blocks.append("\n".join(lines))
    print("\n\n".join(blocks))
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
