# fn-rom Command Rewrite Plan: FujiNet-NIO Integration

## Overview

This document outlines the architectural changes needed to update fn-rom commands to work with fujinet-nio, specifically addressing the removal of the legacy "hosts list" and the adoption of URI-based filesystem selection.

The document `@../fn-rom/docs/fn-rom-bootstrap.md` contains important information about architecture, fn-rom, and fujinet-nio and must be read first.

## Key Architectural Changes

### 1. Hosts List Removal

**Legacy behavior (fujinet-firmware):**
- FujiNet maintained a static list of 8 hosts (URL + prefix pairs)
- Commands like `*FHOST` set host slot numbers (1-8)
- `*FHOST 1` would select the 1st host, `*FHOST 1 http://server/path` would set it

**New behavior (fujinet-nio):**
- No static hosts list - filesystem is specified via URI in each command
- Instead of `*FHOST 1`, use `*FHOST tnfs://server:port/path` or `*FHOST sd0:/`
- The ROM maintains a "current filesystem" state internally (similar to how `*CD` works)

### 2. FujiBus Device IDs

| Device | ID | Purpose |
|--------|-----|---------|
| FujiDevice | 0xFB | FujiNet configuration (hosts, etc.) |
| DiskService | 0xFC | Disk image mount/unmount/IO |
| NetworkService | 0xFD | Network operations |
| FileService | 0xFE | File system operations (list, cd, etc.) |

**Impact:** Commands that previously used FujiDevice (0xFB) for host management should be updated to use DiskService (0xFC) for disk slot operations.

## Current Commands and Rewrite Plan

### Existing Commands (from `cmd_tables.s`)

| Command | Current Behavior | New Behavior Needed |
|---------|-----------------|---------------------|
| `*FHOST` | Set/list host slots (uses FujiDevice 0xFB) | URI-based filesystem selection |
| `*FIN` | Find and mount disk image | Uses current filesystem URI |
| `*FOUT` | Unmount disk | Unmount from slot |
| `*FDRIVE` | List drives | List disk slots |
| `*FLIST` / `*FLS` | List files | Uses current filesystem URI |
| `*FCD` / `*FDIR` | Change directory | Uses current filesystem URI |
| `*FRESET` | Reset FujiNet | Works (uses FujiDevice) |

### Proposed New Commands

Based on MMFS reference and your requirements:

| Command | Syntax | Purpose | FujiBus Target |
|---------|--------|---------|----------------|
| `*FFS` or `*FHOST` | `*FFS tnfs://host:port/path` | Set current filesystem URI | DiskDevice (0xFC) |
| `*FCD` | `*FCD path` | Change directory in current FS | DiskDevice (0xFC) |
| `*FDIR` | `*FDIR` or `*FDIR path` | List directory | DiskDevice (0xFC) |
| `*FLIST` | `*FLIST` | List current directory | DiskDevice (0xFC) |
| `*FIN` | `*FIN <drive> <filename>` | Mount file to drive | DiskDevice (0xFC) |
| `*FOUT` | `*FOUT <drive>` | Unmount drive | DiskDevice (0xFC) |
| `*FDRIVE` | `*FDRIVE` | List mounted drives | DiskDevice (0xFC) |

## FujiBus Protocol for Disk Operations

### Mount Command (0x01)

Request:
```
u8 version = 1
u8 slot (1-8)
u8 flags (bit0 = readonly)
u8 typeOverride (0=auto)
u16 sectorSizeHint
u16 fsNameLen
u8[] fsName (e.g., "tnfs", "sd0")
u16 pathLen
u8[] path (e.g., "/games.atr")
```

### Unmount Command (0x02)

Request:
```
u8 version = 1
u8 slot
```

### Info Command (0x05)

Request:
```
u8 version = 1
u8 slot
```

Response:
```
u8 version
u8 flags (bit0=inserted, bit1=readonly, bit2=dirty, bit3=changed)
u8 slot
u8 type
u16 sectorSize
u32 sectorCount
u8 lastError
```

## ROM State Management

The ROM needs to maintain:

```
; Workspace variables (in $1000-$10FF)
current_fs_type:  .res 1      ; 0=none, 1=tnfs, 2=sd, etc.
current_fs_uri:   .res 64     ; Current URI string (null-terminated)
current_dir:      .res 128    ; Current directory path
```

## Implementation Phases

### Phase 1: Infrastructure
1. Update FujiBus packet sending to use DiskDevice (0xFC)
2. Create new command table entries for updated commands
3. Implement ROM state variables for current filesystem

### Phase 2: Core Commands
1. Rewrite `*FFS` / `*FHOST` - set current filesystem URI
2. Rewrite `*FCD` / `*FDIR` - navigate directories
3. Implement `*FLIST` - list files

### Phase 3: Disk Integration
1. Update `*FIN` - mount to slot using current filesystem
2. Update `*FOUT` - unmount slot
3. Update `*FDRIVE` - show slot status

### Phase 4: Testing
1. Test TNFS navigation
2. Test SD card access
3. Test disk mount/unmount cycles

## Reference: FujiNet-NIO File Device Protocol

See `docs/file_device_protocol.md` for detailed FujiBus protocol.

## Reference: MMFS Command Reference

See `file:///home/markf/dev/bbc/books/MMFSv2-V1.55%20Command%20Reference.pdf`

## Gaps in Current Bootstrap

The current `fn-rom-bootstrap.md` is missing:

1. **FujiBus protocol details** - Which device ID to use for which operations
2. **Command rewrite plan** - How existing commands map to new behavior
3. **State management** - What ROM variables need to track
4. **URI handling** - How to parse and store filesystem URIs

## Recommended Bootstrap Updates

Add a new section to `fn-rom-bootstrap.md`:

```
## Command Rewriting for FujiNet-NIO

This section covers the changes needed to adapt fn-rom commands
from the legacy hosts-list model to the new URI-based model.
```
