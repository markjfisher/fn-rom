#!/usr/bin/env python3
"""Analyse linker map output for ROM size breakdowns."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


MODULE_HEADER_RE = re.compile(r"^(?P<name>[^\s:][^:]*)\.o:$")
SEGMENT_RE = re.compile(
    r"^\s+(?P<segment>\S+)\s+Offs=(?P<offset>[0-9A-F]{6})\s+"
    r"Size=(?P<size>[0-9A-F]{6})\s+Align=(?P<align>[0-9A-F]{5})\s+"
    r"Fill=(?P<fill>[0-9A-F]{4})$"
)


@dataclass
class SegmentBlock:
    """One segment contribution from an object file."""

    name: str
    offset: int
    size: int
    align: int
    fill: int


@dataclass
class ModuleSize:
    """All segment contributions for a single object file."""

    name: str
    blocks: list[SegmentBlock] = field(default_factory=list)

    @property
    def total_size(self) -> int:
        return sum(block.size for block in self.blocks)


def parse_modules(map_path: Path) -> list[ModuleSize]:
    """Parse the map file's Modules list into per-object size data."""
    modules: list[ModuleSize] = []
    current: ModuleSize | None = None
    in_modules = False

    for raw_line in map_path.read_text().splitlines():
        line = raw_line.rstrip()

        if not in_modules:
            if line == "Modules list:":
                in_modules = True
            continue

        if line == "Segment list:":
            break

        match = MODULE_HEADER_RE.match(line)
        if match:
            current = ModuleSize(name=match.group("name"))
            modules.append(current)
            continue

        match = SEGMENT_RE.match(line)
        if match and current is not None:
            current.blocks.append(
                SegmentBlock(
                    name=match.group("segment"),
                    offset=int(match.group("offset"), 16),
                    size=int(match.group("size"), 16),
                    align=int(match.group("align"), 16),
                    fill=int(match.group("fill"), 16),
                )
            )

    if not in_modules:
        raise ValueError(f"No 'Modules list' section found in {map_path}")

    return modules


def format_hex(value: int, width: int = 4) -> str:
    """Format a value as assembler-style uppercase hex."""
    return f"${value:0{width}X}"


def report_sizes(map_path: Path) -> int:
    """Print object sizes by total, with per-segment totals."""
    modules = [module for module in parse_modules(map_path) if module.blocks]
    modules.sort(key=lambda module: (-module.total_size, module.name))

    if not modules:
        print("No module size entries found.", file=sys.stderr)
        return 1

    name_width = max(len(module.name) for module in modules)
    total_width = max(len(format_hex(module.total_size)) for module in modules)

    for module in modules:
        segment_summary = ", ".join(
            f"{block.name}: {format_hex(block.size)}" for block in module.blocks
        )
        print(
            f"{module.name:<{name_width}}  {format_hex(module.total_size):>{total_width}}"
            f"  [{segment_summary}]"
        )

    return 0


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line interface."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--map",
        type=Path,
        default=Path("build/fujinet.rom.map"),
        help="path to linker map file (default: %(default)s)",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser(
        "sizes",
        help="report object file totals with per-segment size breakdowns",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "sizes":
        return report_sizes(args.map)

    parser.error(f"unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
