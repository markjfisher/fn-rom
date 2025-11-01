# `*FIN` Command Architecture

## Executive Summary

The `*FIN` (FujiNet IN) command mounts disk images into virtual drives, equivalent to MMFS's `*DIN` command. This document explains the complete architecture from command parsing to hardware implementation.

## Command Syntax

```
*FIN (<drive>) <disk_name>
```

Examples:
```
*FIN 0 REVS      ; Mount disk "REVS" into drive 0
*FIN TESTDISK0   ; Mount disk "TESTDISK0" into current drive
*FIN 0 GAMES     ; Mount disk "GAMES" into drive 0
*FIN ELITE*      ; Mount first disk matching "ELITE*" into current drive
```

Note: Like MMFS's `*DIN`, the disk name is matched against available disks. If a disk happens to be named "0" or "1", then `*FIN 0 0` would mount a disk named "0" into drive 0, but this is NOT a numeric disk ID - it's a string match.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  COMMAND LAYER                                               │
│  cmd_fin.s: Parses user input via param_drive_and_disk     │
│  Input: "*FIN 0 REVS"                                       │
│  Output: current_drv=0, aws_tmp08/09=<disk_number_for_REVS>│
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  FILE SYSTEM FUNCTIONS                                       │
│  fs_functions.s: load_drive / load_drive_x                  │
│  Orchestrates mount + catalog load                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  MOUNT INTERFACE (Hardware Interface Layer)                 │
│  fuji_mount.s: fuji_mount_disk                              │
│  - Records drive→disk mapping                               │
│  - Manages transactions (&BC-&CB protection)                │
│  - Calls hardware implementation                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  HARDWARE IMPLEMENTATION                                     │
│  fuji_dummy.s:   fuji_mount_disk_data (no-op)              │
│  fuji_serial.s:  fuji_mount_disk_data (send MOUNT command) │
│  fuji_userport.s: fuji_mount_disk_data (send via userport) │
└─────────────────────────────────────────────────────────────┘
```

## Data Structures

### Drive-to-Disk Mapping

```assembly
; os.s
fuji_drive_disk_map = fuji_workspace + $10E0  ; 4 bytes: drives 0-3
; fuji_drive_disk_map[0] = disk number mounted in drive 0
; fuji_drive_disk_map[1] = disk number mounted in drive 1
; fuji_drive_disk_map[2] = disk number mounted in drive 2
; fuji_drive_disk_map[3] = disk number mounted in drive 3
; $FF = no disk mounted
```

### MMFS Equivalent

MMFS uses:
```assembly
DRIVE_INDEX0-3 = disk number low byte
DRIVE_INDEX4-7 = disk number high byte + status flags
```

## Call Flow Detail

### 1. Command Parsing (`cmd_fin.s`)

```assembly
cmd_fs_fin:
        ; Call param_drive_and_disk from fs_functions.s
        ; This parses: (<drive>) <disk_name>
        ; - Calls d_match_init to parse disk name
        ; - Iterates through available disks calling d_match
        ; Sets: current_drv = drive number
        ;       aws_tmp08/09 = disk number (found by name matching)
        jsr     param_drive_and_disk
        
        ; Call load_drive to mount and load catalog
        jmp     load_drive
```

### 2. Load Drive (`fs_functions.s`)

```assembly
load_drive:
        ldx     current_drv
        ; Fall through to load_drive_x

load_drive_x:
        txa
        sta     current_drv             ; Ensure current_drv is set
        
        ; Mount the disk image
        jsr     fuji_mount_disk         ; Records mapping, calls hardware
        
        ; Load catalog from mounted disk
        jsr     load_cur_drv_cat        ; Reads catalog
        rts
```

### 3. Mount Disk (`fuji_mount.s`)

```assembly
fuji_mount_disk:
        jsr     remember_axy
        
        ; Record the mapping
        ldx     current_drv
        lda     aws_tmp08               ; Disk number low byte
        sta     fuji_drive_disk_map,x   ; fuji_drive_disk_map[drive] = disk
        
        ; Call hardware-specific implementation
        jsr     fuji_begin_transaction  ; Protect &BC-&CB
        jsr     fuji_mount_disk_data    ; Hardware layer
        jsr     fuji_end_transaction    ; Restore &BC-&CB
        
        rts
```

### 4. Hardware Implementation

#### Dummy Interface (`fuji_dummy.s`)

```assembly
fuji_mount_disk_data:
        ; No-op for dummy - disks are pre-loaded in RAM
        ; Disk 0 at DRIVE0_CATALOG / DRIVE0_PAGES
        ; Disk 1 at DRIVE1_CATALOG / DRIVE1_PAGES
        rts
```

#### Serial Interface (`fuji_serial.s` - Future)

```assembly
fuji_mount_disk_data:
        ; Build MOUNT command packet
        ; Byte 0: Device ID (0x70)
        ; Byte 1: MOUNT command (0x??)
        ; Byte 2: Drive number (current_drv)
        ; Byte 3-4: Disk number (aws_tmp08/09)
        ; Byte 5: Checksum
        
        jsr     send_fujinet_packet
        jsr     read_fujinet_response
        
        rts
```

## Initialization

### `fuji_init` (`fuji_init.s`)

```assembly
fuji_init:
        ; ... other initialization ...
        
.ifdef FUJINET_INTERFACE_DUMMY
        jsr     fuji_init_ram_filesystem
.endif
        
        ; Initialize drive-to-disk mapping (all unmounted)
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map+0   ; Drive 0
        sta     fuji_drive_disk_map+1   ; Drive 1
        sta     fuji_drive_disk_map+2   ; Drive 2
        sta     fuji_drive_disk_map+3   ; Drive 3
        
        ; ...
```

**Note**: All drives start unmounted (`$FF`). Users must explicitly mount disks using `*FIN` before accessing them. Attempting to access an unmounted drive results in a "Drive empty" error.

## Transaction Management

Like all hardware interface functions, `fuji_mount_disk` protects `&BC-&CB`:

```assembly
fuji_begin_transaction:
    ; Save &BC-&CB (16 bytes) to workspace at $1090
    ldx     #$0F
@save_loop:
    lda     aws_tmp12,x              ; aws_tmp12 = &BC
    sta     $1090,x
    dex
    bpl     @save_loop
    rts

fuji_end_transaction:
    ; Restore &BC-&CB from workspace
    ldx     #$0F
@restore_loop:
    lda     $1090,x
    sta     aws_tmp12,x
    dex
    bpl     @restore_loop
    rts
```

This ensures that parameters in `&BC-&CB` (like exec addresses) are preserved during hardware operations.

## Usage Examples

### Single Drive Mount

```
*FUJI                  ; Activate FujiNet filing system
*FIN 0 TESTDISK0      ; Mount disk "TESTDISK0" into drive 0
*CAT                  ; Show files on the mounted disk
HELLO  WORLD  TEST

*RUN HELLO            ; Run HELLO from the mounted disk
```

### Multi-Drive Operation

```
*FUJI
*FIN 0 TESTDISK0      ; Mount disk "TESTDISK0" into drive 0
*FIN 1 TESTDISK1      ; Mount disk "TESTDISK1" into drive 1

*CAT 0                ; Show files on drive 0
*CAT 1                ; Show files on drive 1

*COPY 0 1 HELLO       ; Copy HELLO from drive 0 to drive 1
```

### Change Mounted Disk

```
*FIN 0 TESTDISK0      ; Mount disk "TESTDISK0" into drive 0
*CAT                  ; Show files from TESTDISK0

*FIN 0 GAMES          ; Mount disk "GAMES" into drive 0
*CAT                  ; Show files from GAMES (different catalog!)
```

## Comparison: MMFS vs FujiNet

| Feature | MMFS | FujiNet |
|---------|------|---------|
| **Command** | `*DIN (<drive>) <name>` | `*FIN (<drive>) <name>` |
| **Disk ID** | String name (e.g., "REVS", "BAS1") | String name (e.g., "TESTDISK0", "GAMES") |
| **Name Matching** | Uppercase, wildcards (*) | Uppercase, wildcards (*) - same as MMFS |
| **Mapping Storage** | DRIVE_INDEX arrays | fuji_drive_disk_map array |
| **Hardware Layer** | MMC SD card operations | Serial/network operations |
| **Dummy Interface** | No dummy | Auto-mount disks for testing |
| **Disk Discovery** | Read from MMC sectors | Query from FujiNet device |

## File Organization

```
src/
├── commands/
│   └── cmd_fin.s              Command parser
├── fs_functions.s             load_drive, param_drive_and_disk
├── fuji_mount.s               High-level mount interface (NEW!)
├── fuji_fs.s                  Transaction management, catalog ops
├── fuji_dummy.s               Dummy hardware implementation
├── fuji_serial.s              Serial hardware implementation (future)
├── fuji_userport.s            User port implementation (future)
└── fuji_init.s                Initialization

docs/
├── DISK_MOUNTING.md           Mounting architecture details
├── FIN_COMMAND_ARCHITECTURE.md This file
└── ARCHITECTURE.md            Overall ROM architecture
```

## Key Design Decisions

### 1. **Layer Separation**

Mount logic is split across layers:
- **Command**: Parses user input
- **File System**: Orchestrates operations
- **Mount Interface**: Records mapping, manages transactions
- **Hardware**: Platform-specific implementation

This allows:
- Dummy interface for testing (no hardware)
- Serial interface for real FujiNet device
- User port interface for alternative connection

### 2. **Disk Name Matching**

Like MMFS, FujiNet uses string name matching:
- Names are converted to uppercase for comparison
- Wildcards (*) supported for ambiguous matches
- Disk matching iterates through available disks using `d_match_init`, `d_match`, etc.
- Internally, matched names resolve to disk numbers for hardware layer

### 3. **Transaction Protection**

`fuji_mount_disk` wraps `fuji_mount_disk_data` with transaction management:
- Protects `&BC-&CB` (exec address, etc.)
- Follows pattern from ARCHITECTURE.md
- Ensures exec addresses survive mount operations

### 4. **No Auto-Mount**

All drives start unmounted:
- All `fuji_drive_disk_map[]` entries initialized to `$FF`
- Users must explicitly use `*FIN` to mount disks
- Accessing unmounted drives gives "Drive empty" error
- Ensures mounting code is properly tested

## Future Enhancements

### 1. **Disk List Command**

```
*FLIST                List available disk images
 0 TESTDISK0
 1 TESTDISK1
 2 GAMES
 3 UTILITIES
```

### 2. **Extension Matching**

Like MMFS, support extension fallback:
```
*FIN REVS             ; Searches for "REVS", then "REVS.SSD", then "REVS.DSD"
```

### 3. **Multi-Drive Conflict Prevention**

Prevent mounting same disk in multiple drives:
```
*FIN 0 GAMES          ; Mount disk "GAMES" to drive 0
*FIN 1 GAMES          ; Should warn or unmount from drive 0 first
```

### 4. **Mount Status Command**

```
*FMOUNTS              Show which disks are mounted
Drive 0: TESTDISK0
Drive 1: GAMES
Drive 2: Not mounted
Drive 3: Not mounted
```

## Testing

### Unit Tests

1. **Mount and Unmount**
   - Mount disk, verify mapping
   - Unmount, verify cleared ($FF)

2. **Multi-Drive**
   - Mount different disks to different drives
   - Verify each drive shows correct catalog

3. **Remount**
   - Mount disk "TESTDISK0" to drive 0
   - Mount disk "TESTDISK1" to drive 0
   - Verify catalog changes

### Integration Tests

1. **File Operations**
   - Mount disk
   - `*CAT`, `*INFO`, `*RUN`
   - Verify correct disk accessed

2. **Cross-Drive Operations**
   - Mount disks to drives 0 and 1
   - `*COPY 0 1 FILE`
   - Verify file copied between disks

## Related Documentation

- `DISK_MOUNTING.md` - Detailed mounting architecture
- `ARCHITECTURE.md` - Overall ROM architecture and transaction management
- `FRESET_COMMAND.md` - Example of serial command implementation

## Summary

The `*FIN` command provides MMFS-like disk mounting for FujiNet:
1. **Clean layer separation** - Command → FS → Mount → Hardware
2. **Transaction management** - Protects critical zero page locations
3. **Multiple implementations** - Dummy (testing), Serial (real), User Port (alternative)
4. **Extensible design** - Easy to add features like disk lists, names, status

The architecture aligns with MMFS patterns while adapting to FujiNet's network-based design.

