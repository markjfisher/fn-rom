# Disk Mounting Architecture

## Overview

FujiNet ROM implements virtual disk mounting similar to MMFS's `*DIN` command. The `*FIN` (FujiNet IN) command mounts disk images into virtual drives.

## MMFS Architecture

In MMFS, multiple .SSD disk image files are stored on the SD card. Users can:

```
*DCAT                  ; List available disk images
BAS1.SSD
BAS2.SSD  
GAMES.SSD

*DIN BAS1.SSD          ; Mount BAS1.SSD into current drive
*CAT                   ; Show files on BAS1.SSD
```

### MMFS Implementation

MMFS tracks which disk is mounted in each drive using `DRIVE_INDEX` arrays:
- `DRIVE_INDEX0-3`: Disk number low byte for drives 0-3
- `DRIVE_INDEX4-7`: Disk number high byte + status flags

When `*DIN` is called:
1. Parse disk name/number
2. Update DRIVE_INDEX for current drive
3. Load catalog from the mounted disk
4. Check CRC and disk status

## FujiNet Architecture

### Drive-to-Disk Mapping

```assembly
; In os.s
fuji_drive_disk_map = fuji_workspace + $10E0  ; 4 bytes: drives 0-3
; Each byte contains the disk image number mounted in that drive
; $FF = no disk mounted
```

### Command Flow: `*FIN <drive> <disk_num>`

```
1. User types: *FIN 0 1

2. cmd_fin.s: cmd_fs_fin
   ↓ Calls param_drive_and_disk
   ↓ Parses drive=0, disk_num=1
   ↓ Sets: current_drv=0, aws_tmp08/09=1

3. fs_functions.s: load_drive
   ↓ Calls fuji_mount_disk

4. fuji_mount.s: fuji_mount_disk
   ↓ Records mapping: fuji_drive_disk_map[0] = 1
   ↓ Calls fuji_mount_disk_data (hardware layer)
   ↓ Returns

5. fs_functions.s: load_drive (continued)
   ↓ Calls load_cur_drv_cat
   ↓ Reads catalog from mounted disk
   ↓ Returns

6. User types: *CAT
   ↓ Shows files from disk image 1 on drive 0
```

### Layer Separation

#### High-Level Layer (`fuji_mount.s`)
- **Function**: `fuji_mount_disk`
- **Purpose**: Records drive→disk mapping, manages transactions
- **Transaction**: Yes (protects &BC-&CB)
- **Calls**: `fuji_mount_disk_data` (hardware layer)

#### Hardware Implementation Layer (`fuji_dummy.s`, `fuji_serial.s`, etc.)
- **Function**: `fuji_mount_disk_data`
- **Purpose**: Hardware-specific mount operation
- **Dummy**: No-op (pre-defined disks always available)
- **Serial**: Send MOUNT command to FujiNet device
- **No Transaction**: Already protected by caller

### Dummy Interface

The dummy interface has 2 pre-defined disk images in RAM:
- **Disk 0 (Drive 0)**: TESTDISC with HELLO, WORLD, TEST files
- **Disk 1 (Drive 1)**: Empty disk NEWDISC  

Since these are hardcoded, mounting is a no-op - they're always available.

### Serial Interface (Future)

For the serial interface, `fuji_mount_disk_data` will:

```assembly
fuji_mount_disk_data:
    ; Build MOUNT command packet
    ; Byte 0: Device ID (0x70)
    ; Byte 1: MOUNT command (0x??)  
    ; Byte 2: Drive number (current_drv)
    ; Byte 3-4: Disk image number (aws_tmp08/09)
    ; Byte 5: Checksum
    
    ; Send packet
    jsr     send_fujinet_packet
    
    ; Wait for ACK
    jsr     read_fujinet_response
    
    rts
```

## Initialization

On ROM initialization (`fuji_init`):
```assembly
; Mark all drives as having no disk mounted
lda     #$FF
sta     fuji_drive_disk_map+0   ; Drive 0
sta     fuji_drive_disk_map+1   ; Drive 1
sta     fuji_drive_disk_map+2   ; Drive 2
sta     fuji_drive_disk_map+3   ; Drive 3
```

## Usage Examples

### Basic Mount and Catalog
```
*FIN 0 0               ; Mount disk 0 into drive 0
*CAT                   ; Show files on disk 0
```

### Multi-Drive
```
*FIN 0 0               ; Mount disk 0 into drive 0
*FIN 1 1               ; Mount disk 1 into drive 1
*CAT 0                 ; Show files on drive 0 (disk 0)
*CAT 1                 ; Show files on drive 1 (disk 1)
```

### File Operations
```
*FIN 0 0               ; Mount disk 0
*INFO HELLO            ; Show info for HELLO on disk 0
*RUN HELLO             ; Run HELLO from disk 0
```

## Comparison: MMFS vs FujiNet

| Aspect | MMFS | FujiNet |
|--------|------|---------|
| **Command** | `*DIN <name>` | `*FIN <drive> <disk_num>` |
| **Disk ID** | String name | Numeric ID |
| **Storage** | DRIVE_INDEX array | fuji_drive_disk_map array |
| **Catalog** | ReadCat7 | fuji_read_catalog |
| **Status** | CRC7, format check | Future: device status |
| **Multi-disk** | Unload from other drives | Future: similar |

## Future Enhancements

1. **Disk List Command** (`*FLIST`): List available disk images
   - Similar to MMFS `*DCAT`
   - Query FujiNet device for disk image list

2. **Auto-Mount**: Mount last-used disks on startup
   - Save mount state to CMOS or config file
   - Restore on *FUJI command

3. **Disk Name Support**: Mount by name instead of number
   - Implement disk matching (d_match_init, etc.)
   - Query device for disk names

4. **Multi-Drive Conflict**: Prevent same disk in multiple drives
   - Check fuji_drive_disk_map before mount
   - Unmount from other drive if needed

## Related Files

- `src/fuji_mount.s` - High-level mount interface
- `src/fuji_dummy.s` - Dummy hardware implementation
- `src/commands/cmd_fin.s` - *FIN command handler
- `src/fs_functions.s` - load_drive/load_drive_x
- `docs/ARCHITECTURE.md` - Overall architecture

