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

## Role split: source layout and build profiles

The ROM is organised so that a feature is in the build **iff its object module is
linked** — there are no inline `.if` feature gates in the command tables or
vector bodies. See [docs/ROM_ROLE_SPLIT_PLAN.md](docs/ROM_ROLE_SPLIT_PLAN.md).

Source is grouped by role under `src/`:

- `src/kernel/` — always compiled: filing-system vectors, transport/channel,
  init, command matcher, the bootstrap mount commands (`*FHOST`/`*FIN`/`*FMOUNT`),
  `*CAT`/`*RUN`, and the command tables (`src/kernel/commands/cmd_tables.s`).
- `src/disk/` — always compiled: DFS catalog + sector IO + the disk vector branch.
- `src/net/` — compiled only when `FEATURE_NET=1`: network FujiBus builders, the
  network vector branch, `*FJSON`, and the OSWORD &78 API.
- `src/utils/` — compiled only when `UTILITIES=resident`: the transient
  management/informational commands. When `UTILITIES=disk` they are built instead
  as standalone `FN-UTLS.ssd` binaries (`scripts/build_fn_utls.sh`).

Build profiles (two orthogonal levers):

| Profile | Command | FEATURE_NET | UTILITIES |
|---------|---------|:-----------:|:---------:|
| ALL      | `make all-rom` / `make all` | 1 | resident |
| DISK+NET | `make net`  | 1 | disk     |
| DISK     | `make disk` | 0 | disk     |

Do **not** reintroduce the retired macros `_FREE_MAP_`, `_UTILS_`, `_ROMS_`; use
the `FEATURE_NET` / `UTILITIES_RESIDENT` defines (set by the Makefile from the
levers) instead. Adding a command means adding a `cmd_entry` fragment in the
right module + group segment; placing the module under the correct `src/<role>/`
directory decides which profiles include it.

`make sizes` reports per-profile ROM usage. `./run_tests.sh` runs the full
build × test matrix; `./run_unit_tests.sh [all|net|disk]` runs the unit tests for
one profile. Beebium scripted tests are tagged by required feature
(`needs_net`, `needs_resident_utils`, `disk_only`) and skip on profiles that
don't provide it (see `integration-tests/beebium/conftest.py`).
