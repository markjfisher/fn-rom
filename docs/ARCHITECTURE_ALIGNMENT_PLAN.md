# Architecture Alignment Plan

## Summary

The current implementation works but bypasses the proper architectural layers. This plan aligns the code with the documented architecture while supporting FujiNet's native mount-slot paradigm.

## Current State

### What We Implemented (Different from Original Design)

The original architecture expected:
- **\*FIN** - Mount disk by name (like MMFS *DIN)
- Disk name matching against available disks
- fuji_drive_disk_map for drive→disk mapping

What we implemented:
- **\*FHOST** - Set host URL
- **\*FIN** - Store filename into FujiNet mount slot
- **\*FMOUNT** - Mount FujiNet slot to BBC drive

This is actually the CORRECT approach for FujiNet! FujiNet has 8 persistent mount slots that work differently from MMFS-style disk selection.

### Current Code Flow (BROKEN)

```
cmd_fmount_c.c
    ↓ (bypasses fuji_mount.s)
fujibus_disk_mount() in fujibus_disk_c.c
    ↓
FujiBus protocol
```

**Problem**: No drive→disk mapping in fuji_drive_disk_map!

### Expected Code Flow

```
cmd_fmount_c.c
    ↓
fuji_mount.s → fuji_mount_disk_data → fujibus_disk_mount
    ↓
fuji_drive_disk_map[current_drv] = slot
```

## Root Cause

1. **fuji_mount_disk** expects parameters: `current_drv` (BBC drive) + `aws_tmp08/09` (disk number)
2. Our implementation uses FujiNet slots (0-7) not disk numbers
3. **fuji_mount_disk_data** in fuji_serial.s is a STUB - not connected to fujibus_disk_mount

## Implementation Plan

### Step 1: Connect fuji_mount_disk_data to FujiBus

In `fuji_serial.s`, implement `fuji_mount_disk_data` to call `fujibus_disk_mount`:

```assembly
; In fuji_serial.s
.import fujibus_disk_mount

fuji_mount_disk_data:
        ; current_drv = BBC drive (0-3)
        ; aws_tmp08/09 = FujiNet slot (repurposed)
        
        ; Get the slot number from fuji_disk_slot (set by *FIN)
        lda     fuji_disk_slot
        sta     aws_tmp08               ; Pass slot as "disk number"
        
        ; Call the FujiBus mount (returns success/fail in carry)
        jsr     fujibus_disk_mount
        
        rts
```

### Step 2: Update cmd_fmount_c.c to use fuji_mount.s

Change from direct call to proper architecture:

```c
// cmd_fmount_c.c - instead of:
if (!fujibus_disk_mount(0)) {
    err_bad_disk_mount();
}

// Should call:
fuji_mount_disk();  // In fuji_mount.s
```

But wait - this requires setting up workspace variables properly.

### Step 3: Understand Parameter Mapping

Looking at fuji_mount_disk:
- Input: `current_drv` = BBC drive (0-3)
- Input: `aws_tmp08/09` = disk number (but we have FujiNet slot)

We need to decide: Should we repurpose aws_tmp08/09 for slot number, or pass slot via a different mechanism?

### Alternative: Hybrid Approach (Recommended)

Keep the direct FujiBus call for the actual mount (since it's working), but also record the mapping in fuji_drive_disk_map:

```c
// In cmd_fmount_c.c after successful mount:
fuji_drive_disk_map[bbc_drive] = fuji_slot;
```

This maintains compatibility while providing the architectural interface.

## Functions to Implement in fuji_serial.s

For full compatibility, implement these STUBS:

| Function | Status | Purpose |
|----------|--------|---------|
| fuji_mount_disk_data | STUB | Mount disk (connect to fujibus_disk_mount) |
| fuji_read_block_data | STUB | Read sector |
| fuji_write_block_data | STUB | Write sector |
| fuji_read_catalog_data | STUB | Read directory |
| fuji_write_catalog_data | STUB | Write directory |
| fuji_read_disc_title_data | STUB | Read disc title |

## Decision Required

**Option A**: Full realignment - make cmd_fmount call fuji_mount_disk
**Option B**: Hybrid - keep direct FujiBus call but record mapping
**Option C**: Leave as-is (works but architecturally incorrect)

The user confirmed FMOUNT works. The main issue is that fuji_drive_disk_map isn't being populated, which could cause issues when other code tries to read it.
