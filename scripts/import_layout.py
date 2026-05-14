"""
Shared helpers for formatting .import / .importzp from symbol names and
parsing ca65 undefined-symbol messages.
"""

from __future__ import annotations

import re
from pathlib import Path

# e.g. src/channels.s:42: Error: Symbol 'foo' is undefined
UNDEF_RE = re.compile(r"^([^:]+):.*Error: Symbol '([^']+)' is undefined")
EXPORTZP_RE = re.compile(r"^\s*\.exportzp\s+(\S+)")
IMPORT_LINE_RE = re.compile(r"^\s*\.import(zp)?\s+\S+")


def parse_exportzp_symbols(os_s: Path) -> set[str]:
    out: set[str] = set()
    text = os_s.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        m = EXPORTZP_RE.match(line)
        if m:
            out.add(m.group(1))
    return out


def normalize_smart_quotes(s: str) -> str:
    return s.replace("\u2018", "'").replace("\u2019", "'")


def tmp_priority_sort_key(name: str) -> tuple[int, int, str] | None:
    """Sort key for aws_tmp / pws_tmp / cws_tmp symbols, or None if not in that set."""
    if name.startswith("aws_tmp"):
        suf = name.removeprefix("aws_tmp")
        n = int(suf) if suf.isdigit() else 10**9
        return (0, n, name)
    if name.startswith("pws_tmp"):
        suf = name.removeprefix("pws_tmp")
        n = int(suf) if suf.isdigit() else 10**9
        return (1, n, name)
    if name.startswith("cws_tmp"):
        suf = name.removeprefix("cws_tmp")
        n = int(suf) if suf.isdigit() else 10**9
        return (2, n, name)
    return None


def import_line(symbol: str, zp_symbols: set[str]) -> str:
    kind = "importzp" if symbol in zp_symbols else "import"
    return f"        .{kind} {symbol}"


def layout_import_lines(symbols: list[str], zp: set[str]) -> list[str]:
    """All .importzp first (tmp scratch, then other ZP), then all .import."""
    tmp = [s for s in symbols if tmp_priority_sort_key(s) is not None]
    zp_other = [s for s in symbols if s in zp and tmp_priority_sort_key(s) is None]
    regular = [s for s in symbols if s not in zp]

    tmp.sort(key=lambda s: tmp_priority_sort_key(s) or (99, 0, s))
    zp_other.sort()
    regular.sort()

    blocks: list[list[str]] = []
    if tmp:
        blocks.append([import_line(s, zp) for s in tmp])
    if zp_other:
        blocks.append([import_line(s, zp) for s in zp_other])
    if regular:
        blocks.append([import_line(s, zp) for s in regular])

    lines: list[str] = []
    for i, block in enumerate(blocks):
        if i:
            lines.append("")
        lines.extend(block)
    return lines


def collect_undefined_for_path(compiler_output: str, source_path: str) -> list[str]:
    """Unique undefined symbols for this source path, in first-seen order."""
    seen: dict[str, None] = {}
    norm = str(Path(source_path).resolve())
    for raw in compiler_output.splitlines():
        line = normalize_smart_quotes(raw)
        m = UNDEF_RE.match(line)
        if not m:
            continue
        err_path, sym = m.group(1), m.group(2)
        if str(Path(err_path).resolve()) != norm:
            continue
        if sym not in seen:
            seen[sym] = None
    return list(seen.keys())
