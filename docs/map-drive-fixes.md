# BBC Drive to FujiNet Slot Map Fixes

## Handoff Summary

This note is for continuing work in a fresh agent session.

### What the overall work is trying to achieve

1. fix the BBC drive to FujiNet mount-slot mapping so BBC drives behave like real removable drives

The mapping fixes are currently documented here and intentionally deferred until enough ROM space has been reclaimed.

### Other useful context

The main deferred drive-map problems are:

- `*FMOUNT` stores the wrong byte in `fuji_drive_disk_map`
- disk I/O currently does not consistently treat `fuji_drive_disk_map[current_drv]` as the authoritative slot source
- an unmapped BBC drive can therefore still appear to show a mounted disk

The rest of this document captures those mapping issues and the intended fix plan.

## Purpose

This document captures the drive mapping issues discovered in `fn-rom` and the changes we want to make.

The goal is to make BBC drive selection behave like a real floppy setup:

- an unmounted BBC drive should use the first fujinet slot if one has previously been configured
- `*FMOUNT <slot> <drive>` should store the correct mapping
- all disk I/O should go through the BBC drive -> FujiNet slot map

## Relevant state

- `fuji_drive_disk_map` defined in os.s
- `current_drv`
- `fuji_disk_slot`

Intended meaning:

- `current_drv` = currently selected BBC drive `0-3`
- `fuji_drive_disk_map[current_drv]` = mapped FujiNet mount slot for that BBC drive
- `$FF` in the map = no disk mounted in that BBC drive
- `fuji_disk_slot` = working slot value used for a specific FujiBus disk request

## Expected behavior

After FujiNet initialization:

- `fuji_drive_disk_map` should be `FF FF FF FF`
- when nothing is mounted in BBC drive 0 `*CAT:0` should automount slot 0 if it has an entry

After `*FMOUNT 0 0`:

- BBC drive 0 should map to FujiNet slot 0 (first index)
- `fuji_drive_disk_map` should become `01 FF FF FF`
- `*CAT:0` should read through that mapping and show the mounted disk

## What was confirmed

### 1. The map is initialized correctly

Both init paths set all four entries to `$FF`.

Files:

- `src/fuji_init.s`
- `src/fuji_fs.s`

This part is correct.

### 2. `*FMOUNT` stores the wrong value in the map

Then `src/fuji_mount.s` writes `aws_tmp08` into `fuji_drive_disk_map[current_drv]`.

That explains why the map becomes:

- `ED FF FF FF`

instead of:

- `01 FF FF FF`

for `*FMOUNT 0 0`.

### 3. Disk reads and writes bypass the drive map

The serial FujiBus disk path currently reads the slot directly from `FUJI_DISK_SLOT`, not from `fuji_drive_disk_map[current_drv]`.

This means a request like `*CAT:0` can still talk to whatever slot value happens to be sitting in `FUJI_DISK_SLOT`, even when the BBC drive is unmapped.

That is why an unmapped drive can appear to contain the first mounted disk.

### 4. Catalog load path does not guard against unmapped drives

`load_cur_drv_cat` in `src/fs_functions.s` calls `fuji_read_catalog` and then marks `current_cat = current_drv`.

There is currently no explicit guard there for:

- `fuji_drive_disk_map[current_drv] == $FF`

So once the lower layer reads a catalog successfully, the current drive is treated as having a loaded catalog even though the drive-to-slot mapping may never have been set up properly.

## Root cause summary

There are two separate bugs:

1. `*FMOUNT` corrupts the map by writing the address of `FUJI_DISK_SLOT` instead of the slot value.
2. The disk I/O path does not treat `fuji_drive_disk_map` as the source of truth for BBC drive selection.

The second bug is the more important architectural problem.

## Intended data flow

The desired flow for all disk operations is:

1. BBC command or file system logic selects `current_drv`
2. resolve `slot = fuji_drive_disk_map[current_drv]`
3. if `slot == $FF`, report drive not mounted / drive empty
4. copy `slot` into `fuji_disk_slot`
5. perform FujiBus disk operation using `fuji_disk_slot`

This should apply to:

- catalog read
- catalog write
- block read
- block write
- memory block read/write helpers

## Changes we want to make later

### Change 1: fix `*FMOUNT` so it stores the slot value

### Change 2: make the map authoritative for disk I/O

Before any disk transaction, resolve:

- `slot = fuji_drive_disk_map[current_drv]`

If the result is `$FF`:

- fail immediately with an existing drive/disk error path

If mapped:

- store it into `fuji_disk_slot`
- continue with FujiBus operation

Best architectural location is likely one small shared helper in assembly, used by:

- `fuji_read_block`
- `fuji_write_block`
- `fuji_read_catalog`
- `fuji_write_catalog`
- `fuji_read_mem_block`
- `fuji_write_mem_block`

### Change 3: add an unmapped-drive guard before catalog load is considered valid

In `src/fs_functions.s`, `load_cur_drv_cat` should not mark:

- `current_cat = current_drv`

unless the drive is actually mapped and the catalog read succeeded.

The guard can be done either:

- directly in `load_cur_drv_cat`, or
- implicitly by making `fuji_read_catalog` fail cleanly when the drive is unmapped

It is still useful for `load_cur_drv_cat` to branch to an existing `err_bad_drive` or similar path if the drive map entry is `$FF`.

## Error behavior to aim for

For an unmapped drive we should not fall back to slot 0 or any stale slot.

Acceptable outcomes:

- `Bad drive`
- `Disc error`
- `Drive empty`

The exact string is less important than the behavior:

- no catalog shown
- no silent fallback
- no accidental access to another mounted disk

## Suggested implementation order

1. Fix the `*FMOUNT` storage bug first.
2. Add one shared helper that resolves the current BBC drive to a FujiNet slot.
3. Call that helper from the disk/catalog entry points before FujiBus access.
4. Reuse an existing error path when the map entry is `$FF`.
5. Verify that `*CAT:0` fails after init and succeeds only after `*FMOUNT`.

## Test cases to run afterwards

### Fresh init

1. Initialize FujiNet
2. Inspect `fuji_drive_disk_map`
3. Expect `FF FF FF FF`
4. Run `*CAT:0`
5. Expect error, not a catalog listing

### Single mount

1. Run `*FMOUNT 1 0`
2. Inspect `fuji_drive_disk_map`
3. Expect `01 FF FF FF`
4. Run `*CAT:0`
5. Expect the disk from FujiNet slot 1

### Different drive

1. Run `*FMOUNT 2 1`
2. Expect map to contain slot 2 for BBC drive 1
3. `*CAT:1` should work
4. `*CAT:0` should still fail if drive 0 is unmapped

### Multiple mounts

1. Map different FujiNet slots to drives 0 and 1
2. Switch between `*CAT:0` and `*CAT:1`
3. Confirm each BBC drive consistently sees its own mapped slot

### Unmount behavior

1. Unmount or clear a drive map entry
2. Confirm the entry returns to `$FF`
3. Confirm `*CAT` on that drive fails immediately

## Short version

The map design is sound, but the implementation is incomplete:

- initialization is correct
- `*FMOUNT` writes the wrong value into the map
- disk I/O does not yet honor the map

When ROM space allows, the fix is:

- store the real slot number in `fuji_drive_disk_map`
- require all disk/catalog I/O to resolve through `current_drv -> fuji_drive_disk_map`
- fail if the map entry is `$FF`
