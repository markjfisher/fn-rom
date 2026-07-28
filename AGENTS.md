# fn-rom agent instructions

## Project Context

This repository contains a BBC Micro ROM implementation for Fujinet connectivity called 'fn-rom'. It's based on MMFS (Multi-Mode File System) and provides enhanced file system functionality for BBC Micro computers, enabling them to access files stored on network-connected storage systems through the Fujinet protocol.

Key features include:
- Standard BBC MOS (Monitor Operating System) compatibility
- File system operations via Fujinet protocol
- Network connectivity support
- Multiple bus interface support (serial, userport, 1MHz)
- *CAT command for directory listing
- Standard BBC OS routines like OSFILE, OSCLI, OSFIND, etc.
- SSD image creation capabilities

## Deeper information about project

Read [fn-rom-bootstrap.md](docs/fn-rom-bootstrap.md) for more context about transport/architecture layers in the project.

## Product source layout

The ROM has one product shape: disk + network device in ROM, with bulky
management/informational commands on the boot/config utilities disk. See
[docs/ROM_ROLE_SPLIT_PLAN.md](docs/ROM_ROLE_SPLIT_PLAN.md).

Source is grouped by role under `src/`:

- `src/kernel/` — always compiled: filing-system vectors, transport/channel,
  init, command matcher, the bootstrap/recovery commands
  (`*FHOST`/`*FIN`/`*FMOUNT`/`*FBOOT`), `*CAT`/`*RUN`, and the command tables
  (`src/kernel/commands/cmd_tables.s`).
- `src/disk/` — always compiled: DFS catalog + sector IO + the disk vector branch.
- `src/net/` — always compiled: network FujiBus builders, the network vector
  branch, `*FJSON`, and the OSWORD &78 API.
- `src/utils/` — disk-only utility sources, built as standalone `FN-BOOT.ssd`
  binaries by `scripts/build_fn_boot.sh`; they are not linked into the resident
  ROM.

Do **not** reintroduce the retired product builds or macros
`_FREE_MAP_`, `_UTILS_`, `_ROMS_`, `UTILITIES_RESIDENT`, or a no-network release
target. Adding a resident command means it is genuinely kernel/protocol/recovery
functionality; utility apps belong on the boot/config disk.

`make sizes` reports ROM usage. `./run_tests.sh` runs the full local test path;
`./run_unit_tests.sh` runs the unit tests. Beebium scripted tests that need the
boot/config disk mounted use `needs_boot_utils_setup` and are covered by the
FN-BOOT command-from-disk lane.
