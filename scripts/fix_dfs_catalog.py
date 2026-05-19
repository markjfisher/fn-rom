#!/usr/bin/env python3
"""
fix_dfs_catalog.py - Rewrite a DFS catalogue into standard descending start-sector order.

This repairs SSD images created by tools that write valid file metadata but emit
catalogue entries in ascending start-sector order. Only the catalogue entries in the
first two sectors are rewritten; file contents and start sectors are left untouched.

Usage:
    ./fix_dfs_catalog.py input.ssd
    ./fix_dfs_catalog.py input.ssd -o fixed.ssd
    ./fix_dfs_catalog.py input.ssd --check
"""

from __future__ import annotations

import argparse
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple


SECTOR_SIZE = 256
CATALOGUE_SIZE = SECTOR_SIZE * 2
MAX_FILES = 31


@dataclass(frozen=True)
class CatalogueEntry:
    file_name: str
    directory: str
    locked: bool
    load_addr: int
    exec_addr: int
    length: int
    start_sector: int

    @property
    def full_name(self) -> str:
        return f"{self.directory}.{self.file_name}"


def parse_catalogue(catalogue: bytes) -> Tuple[bytes, bytes, int, List[CatalogueEntry]]:
    if len(catalogue) != CATALOGUE_SIZE:
        raise ValueError("DFS catalogue must be exactly 512 bytes")

    sector0 = catalogue[:SECTOR_SIZE]
    sector1 = catalogue[SECTOR_SIZE:CATALOGUE_SIZE]

    file_offset = sector1[5]
    file_count = min(file_offset // 8, MAX_FILES)

    entries: List[CatalogueEntry] = []
    for index in range(file_count):
        offset = 8 + index * 8

        raw_name = sector0[offset : offset + 7]
        dir_attr = sector0[offset + 7]
        name = raw_name.decode("latin-1", "replace").rstrip(" \x00")
        if not name:
            continue

        directory = chr(dir_attr & 0x7F) or "$"
        if directory == "\x00":
            directory = "$"
        locked = bool(dir_attr & 0x80)

        b0 = sector1[offset + 0]
        b1 = sector1[offset + 1]
        b2 = sector1[offset + 2]
        b3 = sector1[offset + 3]
        b4 = sector1[offset + 4]
        b5 = sector1[offset + 5]
        b6 = sector1[offset + 6]
        b7 = sector1[offset + 7]

        load_addr = b0 | (b1 << 8) | (((b6 >> 2) & 0x03) << 16)
        exec_addr = b2 | (b3 << 8) | (((b6 >> 6) & 0x03) << 16)
        length = b4 | (b5 << 8) | (((b6 >> 4) & 0x03) << 16)
        start_sector = b7 | ((b6 & 0x03) << 8)

        entries.append(
            CatalogueEntry(
                file_name=name,
                directory=directory,
                locked=locked,
                load_addr=load_addr,
                exec_addr=exec_addr,
                length=length,
                start_sector=start_sector,
            )
        )

    return sector0, sector1, file_count, entries


def make_extra_bits(
    load_addr: int, exec_addr: int, length: int, start_sector: int
) -> int:
    return (
        (((load_addr >> 16) & 0x03) << 2)
        | (((exec_addr >> 16) & 0x03) << 6)
        | (((length >> 16) & 0x03) << 4)
        | ((start_sector >> 8) & 0x03)
    )


def build_catalogue(sector0: bytes, sector1: bytes, entries: List[CatalogueEntry]) -> bytes:
    new_sector0 = bytearray(sector0)
    new_sector1 = bytearray(sector1)

    new_sector0[8:SECTOR_SIZE] = b"\x00" * (SECTOR_SIZE - 8)
    new_sector1[8:SECTOR_SIZE] = b"\x00" * (SECTOR_SIZE - 8)

    for index, entry in enumerate(entries[:MAX_FILES]):
        offset = 8 + index * 8

        name_bytes = entry.file_name.encode("latin-1", "replace")[:7]
        new_sector0[offset : offset + 7] = b" " * 7
        new_sector0[offset : offset + len(name_bytes)] = name_bytes
        new_sector0[offset + 7] = (0x80 if entry.locked else 0) | ord(entry.directory)

        new_sector1[offset + 0] = entry.load_addr & 0xFF
        new_sector1[offset + 1] = (entry.load_addr >> 8) & 0xFF
        new_sector1[offset + 2] = entry.exec_addr & 0xFF
        new_sector1[offset + 3] = (entry.exec_addr >> 8) & 0xFF
        new_sector1[offset + 4] = entry.length & 0xFF
        new_sector1[offset + 5] = (entry.length >> 8) & 0xFF
        new_sector1[offset + 6] = make_extra_bits(
            entry.load_addr, entry.exec_addr, entry.length, entry.start_sector
        )
        new_sector1[offset + 7] = entry.start_sector & 0xFF

    return bytes(new_sector0 + new_sector1)


def entry_sort_key(entry: CatalogueEntry) -> Tuple[int, str, str]:
    return (-entry.start_sector, entry.directory, entry.file_name)


def fix_catalogue_bytes(catalogue: bytes) -> Tuple[bytes, List[CatalogueEntry], List[CatalogueEntry]]:
    sector0, sector1, _file_count, entries = parse_catalogue(catalogue)
    sorted_entries = sorted(entries, key=entry_sort_key)
    return build_catalogue(sector0, sector1, sorted_entries), entries, sorted_entries


def names_with_sectors(entries: List[CatalogueEntry]) -> List[str]:
    return [f"{entry.full_name}={entry.start_sector:#04x}" for entry in entries]


def process_image(input_path: Path, output_path: Path, check_only: bool, verbose: bool) -> int:
    image = input_path.read_bytes()
    if len(image) < CATALOGUE_SIZE:
        print(f"Error: '{input_path}' is smaller than one DFS catalogue", file=sys.stderr)
        return 1

    fixed_catalogue, current_entries, sorted_entries = fix_catalogue_bytes(image[:CATALOGUE_SIZE])
    already_sorted = current_entries == sorted_entries

    if verbose:
        print("Current order:")
        for item in names_with_sectors(current_entries):
            print(f"  {item}")
        print("Desired order:")
        for item in names_with_sectors(sorted_entries):
            print(f"  {item}")

    if check_only:
        if already_sorted:
            print(f"Catalogue already ordered correctly: {input_path}")
            return 0
        print(f"Catalogue needs fixing: {input_path}")
        return 2

    if already_sorted and input_path.resolve() == output_path.resolve():
        print(f"Catalogue already ordered correctly: {input_path}")
        return 0

    output_bytes = fixed_catalogue + image[CATALOGUE_SIZE:]
    if input_path.resolve() != output_path.resolve():
        shutil.copyfile(input_path, output_path)
    output_path.write_bytes(output_bytes)

    if already_sorted:
        print(f"Wrote unchanged image: {output_path}")
    else:
        print(f"Reordered DFS catalogue: {output_path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rewrite a DFS catalogue into descending start-sector order"
    )
    parser.add_argument("ssd", type=Path, help="Input SSD image")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output SSD image (default: rewrite input in place)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check ordering only; exit 0 if OK, 2 if reordering is needed",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print catalogue order before and after sorting",
    )

    args = parser.parse_args()
    output_path = args.output or args.ssd
    return process_image(args.ssd, output_path, args.check, args.verbose)


if __name__ == "__main__":
    sys.exit(main())
