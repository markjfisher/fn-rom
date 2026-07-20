# fn-rom (FujiNet ROM) Architecture

## Overview

fn-rom implements a BBC Micro Disk Filing System (DFS) compatible interface that communicates with fujiNet-nio hardware over a network connection. The architecture is based on MMFS (Master Micro Filing System) but adapted for network operations instead of MMC/SD card access.
This will typically be burned as a pysical ROM, or loaded as a ROM image into a bbc emulator.

## fujinet-nio

fujinet-nio is a clean rewrite of FujiNet firmware. It targets multiple platforms (notably **POSIX** and **ESP32**) while keeping most logic **platform-agnostic**.

It is designed to:

- Run on **ESP32-S3 (ESP-IDF, TinyUSB)**  
- Run on **POSIX systems** (Linux/macOS)  
- Be embeddable as a **native library**  
- Integrate with **emulators**  

At the heart of the design is a clean separation between:

| Layer | Purpose |
|-------|---------|
| **Channels** | Raw byte I/O (USB CDC, PTY, TCP, UART, …) |
| **Transports** | Framing (SLIP), FujiBus encode/decode → IORequest/IOResponse |
| **Core** | Request routing, ticking, device lifecycle |
| **Devices** | Virtual devices (Disk, Fuji config, Network, Printer, …) |

### FujiBus Device IDs (for fn-rom commands)

| Device | ID | Purpose |
|--------|-----|---------|
| FujiDevice | 0xFB | FujiNet configuration (legacy hosts) |
| DiskService | 0xFC | Disk image mount/unmount/IO |
| FileService | 0xFE | File system operations (list, cd) |

### Key Architectural Change: No Static Hosts List

**Legacy (fujinet-firmware):** FujiNet maintained a static list of 8 hosts (URL + prefix pairs).

**New (fujinet-nio):** No static hosts list. Filesystem is specified via **URI** in each command (e.g., `tnfs://server:port/path`, `sd0:/`).

The ROM must maintain "current filesystem" state internally.

## fn-rom transport and channel

The transport used by fn-rom is FujiBus (header, descriptors and payload definition) with SLIP framing. FujiBus packet logic lives in `@src/fujibus.s`, and shared SLIP framing lives in `@src/fuji_link_slip.s`.

Shared FujiBus-backed data operations live in `@src/fuji_data_fujibus.s` and the device-specific command builders live in `@src/fujibus_disk.s`, `@src/fujibus_fuji.s`, and `@src/fujibus_network.s`.

The channel is the raw byte stream beneath SLIP and FujiBus. Today that channel is serial data over PTY or RS423/RS232, implemented in `@src/serial/`. Future userport or 1MHz support should provide the same `fuji_link_*` raw-link entry points without duplicating the SLIP or FujiBus layers.

## Disk support

fujinet-nio supports:
- SSD images `@/src/lib/disk/ssd_image.cpp`
- a virtual filesystem to support mounting ssd images (e.g. TNFS (Trivial Network File System), SD, Flash)

## MOS interface for fn-rom

fn-rom supports commands to interact with the ROM as standard MOS commands.
As well as all the standard commands like *CAT, *DISC, *ENABLE, etc. we also have "FujiNet" commands that start with "*F", e.g. "*FRESET" to send a command to the fujinet to reset.
The command **matcher and tables** live in `@src/kernel/commands/` (notably
`cmd_tables.s`, which declares the base command groups); individual command
handlers live under the role directory that owns them (`src/kernel/`,
`src/disk/`, `src/net/` or `src/utils/`). Each handler self-registers into a
command group with the `cmd_entry` macro (`src/inc/macros.inc`), so a command is
present in a build iff its object module is linked — see the role split below.

## Role split (build profiles)

Source is grouped by role so feature membership is decided by *which object
modules are linked*, not by inline `.if`. Two orthogonal levers select a profile
(full detail in `docs/ROM_ROLE_SPLIT_PLAN.md`):

| Dir | Always built? | Gate |
|-----|---------------|------|
| `src/kernel/` | yes | — (vectors, transport, channel, init, matcher, `*FHOST`/`*FIN`/`*FMOUNT`, `*CAT`/`*RUN`) |
| `src/disk/`   | yes | — (DFS catalog + sector IO + disk vector branch) |
| `src/net/`    | no  | `FEATURE_NET=1` (network branch, `*FJSON`, OSWORD &78) |
| `src/utils/`  | no  | `UTILITIES=resident` (management/informational commands) |

Profiles: **ALL** (`make all-rom`, net + utils resident), **DISK+NET**
(`make net`, the default ship build, utils on disk) and **DISK** (`make disk`,
no network). The retired macros `_FREE_MAP_`/`_UTILS_`/`_ROMS_` were folded into
these levers.

### Transient utilities and their ROM ABI

When `UTILITIES=disk`, the management/informational commands are not in the ROM;
they ship on `FN-UTLS.ssd` and load on demand via the standard MOS
unrecognised-command → filing-system `*RUN` fallthrough (service &04 is left
unclaimed, so the MOS asks the FS to run the command as a file, using the
library-aware lookup so it resolves from the utils/library drive regardless of
the current drive).

Each transient utility is a standalone RAM binary loaded and entered by the FS
`*RUN` path. BBC utility binaries load/exec at `$1900`; Master utility binaries
load/exec at `$0E00`, which is another reason the release ships separate
`FN-UTLS.ssd` and `FN-UTLS-M.ssd` images. The generated wrapper calls resident
ROM routines through the stable utility ABI table at `$8030`
(`src/kernel/util_abi.s`). The table is a sequence of fixed-address `JMP`
veneers; the real resident implementations can move inside the ROM as long as
the table start and slot order are preserved.

`scripts/build_fn_utls.sh` builds the `UTILITIES=disk` ROM, turns its label file
into `rom_abi.s`, and links each utility against it. Routine imports are mapped
to the fixed `$8030` table slots; direct workspace/data imports are mapped to
the target machine's real label addresses. That means a utility disk is no
longer tied to one exact ROM layout for code movement, but BBC and Master still
need separate utility disks today because their workspace/data addresses differ.
Each generated utility wrapper runs from RAM, scans sideways ROM slots for the
`FujiNet` service ROM plus the `FNABI1` ABI signature, and leaves that ROM paged
before entering the table. If the ROM/signature is missing it prints
`FujiNet ROM ABI not found` and returns to the MOS instead of jumping through
whatever ROM happens to be active.

Utils-internal helpers shared only between utilities are duplicated into the
binary (cost is disk, not ROM), never promoted to a resident ROM entry point. A
small wrapper (`utils-bin/<cmd>.s`) sets up the command line and calls the
resident handler, exiting via `exit_user_ok`. The FS ROM is paged in while an
`*RUN` command from the FS executes, so the table `jsr`s into the ROM are valid.

## Compiling and Source

Source is 6502 assembly language, using ca65 dialect, using cc65 to compile to ROM.
`make` is used to build from the root of fn-rom project using `@Makefile`

## Important restrictions

- ROM code cannot use cc65's C stack for creating temporary variables, or use "BSS" segments for variables as we are compiling to a ROM.
- Certain ZeroPage locations are available as temporary work values (see `@src/os.s`)
  - Command Workspace Locations cws_tmp1 to cws_tmp9 - When dealing with MOS commands
  - Absolute Workspace Locations aws_tmp00 to aws_tmp15 - General workspace variables to use
  - Private Workspace Locations pws_tmp00 to pws_tmp15 - remain unaltered if the filing system remains selected
- These ZP locations are reusable, and should be treated as volatile when calling between functions, as their values may be changed.

## Memory constraints

BBC ROM code working space can only fit up to $1900 hex in memory. The authoritative buffer and workspace layout is in `@src/os.s` (fuji_* symbols) and `@src/fujibus.s` (FujiBus TX/RX and the memory map comments there).
