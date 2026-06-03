#!/usr/bin/env python3
"""Report ROM size usage from cl65/ld65 .map files.

For each map file:
  * Segment summary  -> bytes used in the MAIN sideways-ROM region and bytes free.
  * Module breakdown -> per-object-module contribution (from the "Modules list").
  * Feature subtotals-> modules grouped by the planned role-split feature
                        (kernel / disk / net / utils / vectors-mixed), so we can
                        size the DISK / DISK+NET / ALL builds before the source
                        is reorganised. See docs/ROM_ROLE_SPLIT_PLAN.md.

The feature grouping is a Phase-0 *estimate*: cleanly-separable modules
(fujibus_network, fnnet, the cmd_*.o command files) are attributed exactly, but
the shared MOS filing vectors carry both disk and network branches in one object
module and cannot be split until Phase 2 — those are reported as "vectors-mixed".

Usage:
    scripts/rom_sizes.py build/fujinet.rom.map [build/fujinet-master.rom.map ...]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# MAIN sideways-ROM region from cfg/fujinet-rom.cfg: $8000..$BFFF (16 KB).
MAIN_START = 0x8000
MAIN_SIZE = 0x4000
MAIN_END_EXCL = MAIN_START + MAIN_SIZE  # 0xC000

# Feature classification by object-module basename (without .o).
# Anything not listed falls into "kernel" (always-resident core), and is
# reported in an "unclassified" note so nothing is hidden.
NET = {
    "fujibus_network",   # network FujiBus command builders
    "fnnet",             # OSWORD &78 network API (long URIs / JSON)
    "cmd_fjson",         # *FJSON (thin wrapper; resident in NET builds)
}
# Transient management/informational commands -> utilities SSD (Lever B).
UTILS = {
    "cmd_copy", "cmd_wipe", "cmd_destroy", "cmd_rename", "cmd_access",
    "cmd_title", "cmd_info", "cmd_fs_fnew", "cmd_fout", "cmd_funmount",
    "cmd_free_map", "cmd_verify_format", "confirm",
    "cmd_fcd", "cmd_flist", "cmd_fdrive", "flist_resolve_target",
}
# Disk catalog / sector IO / disk-side of the filing operations (always present,
# but sized here so we understand the base).
DISK = {
    "fs_functions", "fujibus_disk", "fuji_mount", "fuji_fs", "fastgb",
    "gbpb_functions", "fuji_execute_block_rw", "osfileFF_loadfiletoaddr",
    "osfile_functions", "osfile_helpers", "cmd_cat",
}
# Shared MOS filing-vector shells: kernel skeleton + disk branch + net branch in
# one module. Not separable until Phase 2.
VECTORS_MIXED = {
    "argsv_entry", "bgetv_entry", "bputv_entry", "filev_entry",
    "filing_vectors", "findv_entry",
}

GROUP_ORDER = ["kernel", "disk", "vectors-mixed", "net", "utils"]


def classify(module: str) -> str:
    if module in NET:
        return "net"
    if module in UTILS:
        return "utils"
    if module in DISK:
        return "disk"
    if module in VECTORS_MIXED:
        return "vectors-mixed"
    return "kernel"


def parse_segments(text: str) -> dict[str, tuple[int, int, int]]:
    """Return {segment: (start, end, size)} from the 'Segment list' section."""
    out: dict[str, tuple[int, int, int]] = {}
    in_section = False
    for line in text.splitlines():
        if line.startswith("Segment list:"):
            in_section = True
            continue
        if in_section:
            if line.startswith("Exports list") or line.startswith("Modules list"):
                break
            m = re.match(r"^(\S+)\s+([0-9A-Fa-f]{6})\s+([0-9A-Fa-f]{6})\s+([0-9A-Fa-f]{6})", line)
            if m:
                name, start, end, size = m.group(1), int(m.group(2), 16), int(m.group(3), 16), int(m.group(4), 16)
                out[name] = (start, end, size)
    return out


def parse_modules(text: str) -> dict[str, dict[str, int]]:
    """Return {module: {segment: size}} from the 'Modules list' section."""
    out: dict[str, dict[str, int]] = {}
    in_section = False
    current: str | None = None
    for line in text.splitlines():
        if line.startswith("Modules list:"):
            in_section = True
            continue
        if in_section:
            if line.startswith("Segment list:"):
                break
            m = re.match(r"^(\S+\.o):\s*$", line)
            if m:
                current = m.group(1)[:-2]  # strip ".o"
                out.setdefault(current, {})
                continue
            m = re.match(r"^\s+(\S+)\s+Offs=[0-9A-Fa-f]+\s+Size=([0-9A-Fa-f]+)", line)
            if m and current is not None:
                out[current][m.group(1)] = int(m.group(2), 16)
    return out


def report(map_path: Path) -> None:
    text = map_path.read_text()
    segs = parse_segments(text)
    mods = parse_modules(text)

    used = max((end for _, end, _ in segs.values()), default=MAIN_START - 1) - MAIN_START + 1
    free = MAIN_END_EXCL - MAIN_START - used

    print(f"\n=== {map_path.name} ===")
    print(f"  MAIN region : ${MAIN_START:04X}-${MAIN_END_EXCL - 1:04X} ({MAIN_SIZE} bytes)")
    for name in ("HEADER", "RO_EARLY", "RODATA", "CODE"):
        if name in segs:
            start, end, size = segs[name]
            print(f"    {name:<9} ${start:04X}-${end:04X}  {size:5d} B")
    pct = 100.0 * used / MAIN_SIZE
    print(f"  USED        : {used:5d} B ({pct:.1f}%)")
    print(f"  FREE        : {free:5d} B")

    # Feature subtotals.
    group_tot: dict[str, int] = {g: 0 for g in GROUP_ORDER}
    group_mods: dict[str, list[tuple[str, int]]] = {g: [] for g in GROUP_ORDER}
    for module, segsizes in mods.items():
        total = sum(segsizes.values())
        if total == 0:
            continue  # include-only / pure-symbol modules
        g = classify(module)
        group_tot[g] += total
        group_mods[g].append((module, total))

    print("  feature subtotals (Phase-0 estimate):")
    for g in GROUP_ORDER:
        print(f"    {g:<14} {group_tot[g]:5d} B")
    print(f"    {'TOTAL':<14} {sum(group_tot.values()):5d} B")

    # The actionable deltas for the role split.
    net = group_tot["net"]
    utils = group_tot["utils"]
    print("  role-split deltas (cleanly-separable modules only):")
    print(f"    drop NET feature (DISK build)        : -{net} B")
    print(f"    move UTILS to disk (DISK & DISK+NET)  : -{utils} B")
    print(f"    DISK build reclaim (NET+UTILS)        : -{net + utils} B  -> ~{free + net + utils} B free")
    print(f"    DISK+NET reclaim (UTILS only)         : -{utils} B  -> ~{free + utils} B free")


def main(argv: list[str]) -> int:
    paths = [Path(p) for p in argv[1:]]
    if not paths:
        print(__doc__)
        return 2
    missing = [p for p in paths if not p.exists()]
    if missing:
        for p in missing:
            print(f"map not found: {p} (build first)", file=sys.stderr)
        return 1
    for p in paths:
        report(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
