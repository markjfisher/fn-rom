# Removing Auto-Mount from Dummy Interface

## Problem

The dummy interface was auto-mounting disk images on initialization, which caused several issues:

1. **Can't test `*FIN` command** - Disks were already mounted, so `*FIN` appeared to work but wasn't actually exercising the mount path
2. **Cheating in dummy implementation** - The dummy interface pretended disks were mounted without going through proper mount process
3. **No unmount testing** - Without `*DOUT` (unmount) command implemented, we have no way to unmount and remount
4. **False confidence** - Tests passed because of pre-mounted state, not because mounting actually worked

## Solution

Removed auto-mounting and properly implemented mount state checking.

### Changes Made

#### 1. `src/fuji_init.s` - Initialize All Drives as Unmounted

**Before:**
```assembly
.ifdef FUJINET_INTERFACE_DUMMY
        jsr     fuji_init_ram_filesystem
        
        ; Auto-mount the dummy disk images
        ; Disk 0 → Drive 0, Disk 1 → Drive 1
        lda     #$00                    ; Disk 0
        sta     fuji_drive_disk_map+0   ; Mount to drive 0
        lda     #$01                    ; Disk 1
        sta     fuji_drive_disk_map+1   ; Mount to drive 1
.endif
```

**After:**
```assembly
.ifdef FUJINET_INTERFACE_DUMMY
        jsr     fuji_init_ram_filesystem
.endif
        
        ; Initialize drive-to-disk mapping (all unmounted)
        lda     #$FF                    ; $FF = no disk mounted
        sta     fuji_drive_disk_map+0   ; Drive 0
        sta     fuji_drive_disk_map+1   ; Drive 1
        sta     fuji_drive_disk_map+2   ; Drive 2
        sta     fuji_drive_disk_map+3   ; Drive 3
```

**Key Changes:**
- Removed conditional auto-mount for dummy interface
- Initialize ALL drives (0-3) to `$FF` (unmounted)
- Initialization now happens unconditionally (not just for dummy)

#### 2. `src/fuji_dummy.s` - Check Mount State in Get Functions

Updated three critical functions to check `fuji_drive_disk_map` before returning disk data:

##### `get_current_catalog`

**Before:**
```assembly
get_current_catalog:
        lda     current_drv
        beq     @drive0
        ; Drive 1
        lda     #<DRIVE1_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE1_CATALOG
        sta     aws_tmp13
        rts
@drive0:
        ; Drive 0
        lda     #<DRIVE0_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE0_CATALOG
        sta     aws_tmp13
        rts
```

**After:**
```assembly
get_current_catalog:
        ; Check which disk is mounted in current_drv
        ldx     current_drv
        lda     fuji_drive_disk_map,x
        cmp     #$FF                     ; Is anything mounted?
        beq     @unmounted_error
        
        ; A = disk number (0 or 1 for dummy)
        beq     @disk0
        ; Disk 1
        lda     #<DRIVE1_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE1_CATALOG
        sta     aws_tmp13
        rts
@disk0:
        ; Disk 0
        lda     #<DRIVE0_CATALOG
        sta     aws_tmp12
        lda     #>DRIVE0_CATALOG
        sta     aws_tmp13
        rts
        
@unmounted_error:
        ; No disk mounted in this drive
        jsr     err_bad
        .byte   $D6                      ; "Drive empty" error
        .byte   "Drive empty", 0
```

**Key Changes:**
- Check `fuji_drive_disk_map[current_drv]` first
- If `$FF`, throw "Drive empty" error
- Otherwise, use disk number to determine which catalog to return

##### `get_current_page_alloc` and `get_current_pages_start`

Both functions updated with identical logic:
- Check mount state via `fuji_drive_disk_map`
- Return "Drive empty" error if unmounted
- Use disk number to determine correct page allocation/pages area

## Testing Strategy

Now we can properly test the mounting system:

### 1. Test Unmounted State
```
*FUJI                    ; Activate filing system
*CAT                     ; Should show "Drive empty" error
```

### 2. Test Mount
```
*FIN 0 TESTDISK0        ; Mount disk 0 into drive 0
*CAT                     ; Should now show catalog
```

### 3. Test Multi-Drive
```
*FIN 0 TESTDISK0        ; Mount disk 0 into drive 0
*FIN 1 TESTDISK1        ; Mount disk 1 into drive 1
*CAT 0                   ; Show drive 0 files
*CAT 1                   ; Show drive 1 files
```

### 4. Test Remount
```
*FIN 0 TESTDISK0        ; Mount disk 0
*CAT                     ; Show TESTDISK0 files
*FIN 0 TESTDISK1        ; Mount disk 1 over drive 0
*CAT                     ; Should show TESTDISK1 files now
```

### 5. Test Unmount (when `*DOUT` implemented)
```
*FIN 0 TESTDISK0        ; Mount
*CAT                     ; Works
*DOUT 0                  ; Unmount
*CAT                     ; Should show "Drive empty"
```

## Benefits

1. **Honest Implementation** - Mounting actually goes through proper code paths
2. **Testable** - Can now verify `*FIN` command works correctly
3. **Error Handling** - Proper "Drive empty" errors when accessing unmounted drives
4. **Future-Ready** - Prepared for `*DOUT` (unmount) command implementation
5. **Realistic Behavior** - Matches real hardware behavior where drives start unmounted

## Error Code

**Error $D6: "Drive empty"**
- Thrown when attempting to access an unmounted drive
- Compatible with BBC DFS error codes
- Clear message for users

## Implementation Notes

### Dummy Interface Disk Mapping

The dummy interface has two disk images pre-loaded in RAM:
- **Disk 0**: TESTDISK0 (at DRIVE0_CATALOG, DRIVE0_PAGES)
- **Disk 1**: TESTDISK1 (at DRIVE1_CATALOG, DRIVE1_PAGES)

But they are NOT mounted until `*FIN` is used:
```
fuji_drive_disk_map[0] = $FF    ; Drive 0: unmounted
fuji_drive_disk_map[1] = $FF    ; Drive 1: unmounted
fuji_drive_disk_map[2] = $FF    ; Drive 2: unmounted
fuji_drive_disk_map[3] = $FF    ; Drive 3: unmounted
```

After `*FIN 0 TESTDISK0`:
```
fuji_drive_disk_map[0] = $00    ; Drive 0: disk 0 mounted
```

### Serial Interface

For the serial interface, the same logic applies:
- All drives start unmounted (`$FF`)
- `fuji_mount_disk_data` will send mount command to FujiNet device
- Device returns disk data over serial connection
- Catalog loaded into workspace

## Related Documentation

- `FIN_COMMAND_ARCHITECTURE.md` - Complete `*FIN` command architecture
- `DISK_MOUNTING.md` - Disk mounting architecture details
- `DISK_MATCH_TRANSLATION.md` - Disk name matching implementation

## Summary

By removing auto-mounting, we've created an honest, testable implementation that:
- Properly exercises the mount code path
- Provides clear error messages for unmounted drives
- Matches realistic hardware behavior
- Prepares for future `*DOUT` unmount command
- Gives confidence that `*FIN` actually works

The dummy interface still provides two disk images in RAM for testing, but they must be explicitly mounted with `*FIN` before use.

