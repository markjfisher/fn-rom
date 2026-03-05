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

The transport used by fn-rom is fujibus (header, descriptors and payload definition) with SLIP framing. See `@../fn-rom/src/fujibus.s`.

The channel is SERIAL data over either PTY for virtual connections, or rs232 connecting to an esp32 device. See `@../fn-rom/src/fuji_serial.s` 

## Disk support

fujinet-nio supports:
- SSD images `@/src/lib/disk/ssd_image.cpp`
- a virtual filesystem to support mounting ssd images (e.g. TNFS (Trivial Network File System), SD, Flash)

## MOS interface for fn-rom

fn-rom supports commands to interact with the ROM as standard MOS commands.
As well as all the standard commands like *CAT, *DISC, *ENABLE, etc. we also have "FujiNet" commands that start with "*F", e.g. "*FRESET" to send a command to the fujinet to reset.
All commands are in the folder `@../fn-rom/src/commands/` folder.
The file `@../fn-rom/src/commands/cmd_tables.s` defines the commands and what function should be invoked when the user issues a command.

## Compiling and Source

Source is 6502 assembly language, using ca65 dialect, using cc65 to compile to ROM.
`make` is used to build from the root of fn-rom project using `@../fn-rom/Makefile`

## Important restrictions

- ROM code cannot use cc65's C stack for creating temporary variables, or use "BSS" segments for variables as we are compiling to a ROM.
- Certain ZeroPage locations are available as temporary work values (see `@../fn-rom/src/os.s`)
  - Command Workspace Locations cws_tmp1 to cws_tmp9 - When dealing with MOS commands
  - Absolute Workspace Locations aws_tmp00 to aws_tmp15 - General workspace variables to use
  - Private Workspace Locations pws_tmp00 to pws_tmp15 - remain unaltered if the filing system remains selected
- These ZP locations are reusable, and should be treated as volatile when calling between functions, as their values may be changed.

## Memory constraints

BBC ROM code working space can only fit up to $1900 hex in memory.
The layout is as follows:

; ============================================================================
; Buffers - Memory-efficient layout staying under PAGE ($1900)
; ============================================================================
; Memory map:
; $0E00-$0FFF - Catalog area (512 bytes) - also used for large RX ops
; $1000-$10FF - FujiNet workspace variables
; $1100-$111F - Channel workspace
; $1120-$115F - FujiBus TX buffer (64 bytes)
; $1160-$135F - FujiBus RX buffer (512 bytes)
; $1360-$18FF - Available for future use
; $1900       - PAGE limit (DO NOT EXCEED!)
; ============================================================================
