# Phase 1 — Composable command table (results)

Per `docs/BOOT_DISK_PLAN.md` §5.3 / §6 Phase 1. Goal: retire the inline `.if` in the command
tables in favour of a linker-segment-collected table, proven on the FREE/MAP feature.

## What changed

- **`cmd_entry` macro** (`src/inc/macros.inc`) — declares one command, emitting its matched text +
  param bytes into a per-group `CMDSTR_<grp>` segment and its handler address into the parallel
  `CMDADR_<grp>` segment. String and address are emitted together, so they can never drift apart.
- **`cmd_tables.s`** rebuilt declaratively on `cmd_entry`. Groups: FUJIFS, FUTILS, UTILS, FS, HELP.
- **Per-group segments** (`cfg/fujinet-rom.cfg`). A group's base segment has a single owner
  (`cmd_tables.s`), so its start label is reliable regardless of object link order. A feature module
  *extends* a group by appending into the contiguous `_EXT` segment; a one-byte `_T` segment carries
  the `$00` terminator after any extension. FUTILS is placed last so the help printer detects an
  "F"-prefixed command with a single `>= cmd_str_futils` compare.
- **Matcher** (`src/services/service09.s`) walks a group's CMDSTR run to its `$00` and dispatches via
  the group's CMDADR base by entry position. Group id is carried on the stack (ZP `aws_tmp` is not
  safe across the MOS `GSINIT`/`GSREAD` calls); the per-group descriptor (`grp_str`/`grp_adr`/
  `grp_not`) replaces the old count-prefix-as-base-index and low-byte `cmdtab_offset_*` tricks.
- **`help.s`** walks each group to its terminator; the leading "F" check retargets to `cmd_str_futils`.
- **FREE/MAP** self-register from `cmd_free_map.s` into `FUJIFS_EXT` (`cmd_entry "FUJIFS_EXT", ...`).
  The whole file is built only when `_FREE_MAP_` is defined, so the commands are present iff the
  feature is built — **there is no `.if` in the command table.**

## Verification

- **Default build (no FREE_MAP):** beebium scripted suite **19 passed, 2 skipped** — identical to the
  Phase 0 golden baseline. Behaviour preserved.
- **`FREE_MAP=1` build:** beebium scripted suite **19 passed, 2 skipped** — the longer fujifs walk
  (FUJIFS → EXT → `$00`) and group chaining are intact with the extension present.
- **FREE/MAP registration (static, `FREE_MAP=1`):** `CMDSTR_FUJIFS_EXT` = `"FREE",$84,$00,"MAP",$84,$00`
  contiguous after the base group and before the `$00`; `CMDADR_FUJIFS_EXT` = `cmd_fs_free-1`,
  `cmd_fs_map-1`; the entries land at combined index 16/17 in both the string and address arrays
  (`cmd_adr_fujifs` + 2·16 = `CMDADR_FUJIFS_EXT`). Dispatch is the same proven path used by every other
  command, so `*FREE`/`*MAP` reach their handlers.

> Note: the beebium suite does not exercise `*FREE`/`*MAP` themselves; their correctness rests on the
> static table verification plus the matcher being proven by the 19/19 pass on both builds.

## Size (default build)

| Build | Phase 0 used / free | Phase 1 used / free |
|-------|--------------------:|--------------------:|
| BBC    | 15570 / 814 | 15550 / 834 |
| Master | 15606 / 778 | 15586 / 798 |

~20 B smaller (dropped the count-prefix bytes and `set_cmd_table_ptr_x`, net of the new descriptor).

## Acceptance

- [x] `cmd_entry` macro + segment-collected table implemented (§5.3).
- [x] FREE/MAP migrated off `.if .defined(_FREE_MAP_)`; no `.if` left for FREE/MAP in the tables.
- [x] Command behaviour preserved (beebium green on both default and `FREE_MAP=1`).

## Still gated by `.if` (out of Phase 1 scope; retire in Phase 5)

`_ROMS_` / `_UTILS_` still gate the ROMS command and the UTILS help topic in `cmd_tables.s`. These are
declared with `cmd_entry` now, just wrapped in `.if`; folding them in is Phase 5 cleanup.
