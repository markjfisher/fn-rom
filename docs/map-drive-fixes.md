# BBC Drive to FujiNet Slot Map Fixes

## Handoff Summary

This note is for continuing work in a fresh agent session.

### What the overall work is trying to achieve

There are two parallel goals:

1. fix the BBC drive to FujiNet mount-slot mapping so BBC drives behave like real removable drives
2. reduce ROM usage by rewriting large cc65-generated C code back into 6502 assembly

The mapping fixes are currently documented here and intentionally deferred until enough ROM space has been reclaimed.

### Why the mapping fixes were deferred

The original implementation work was hitting ROM limits. Several straightforward fixes for the drive map logic worked conceptually, but overflowed the ROM.

Because of that, the immediate priority changed to:

- identify the largest C-generated objects in the ROM
- port them back to assembly
- then apply the drive-map fixes once there is enough headroom

### Current ROM-reduction work already performed

We targeted `fujibus_disk_c.c` first because it was one of the largest C objects in the ROM.

Before rewrite:

- `fujibus_disk_c.o` contributed `0x0CF9` bytes of `CODE` in the ROM map

After rewrite:

- the live functionality was moved into `src/fujibus_disk.s`
- `src/fujibus_disk_c.c` was reduced to an empty translation unit
- `fujibus_disk.o` now contributes `0x0341` bytes of `CODE`
- net ROM saving is about `0x09B8` bytes (`2488` bytes)

### Functions moved from C to ASM

The following entry points were implemented in `src/fujibus_disk.s`:

- `_fujibus_disk_mount`
- `_fujibus_disk_read_sector`
- `_fujibus_disk_write_sector_current`
- `_fujibus_resolve_path`

This was done because these are the currently live entry points used by the ROM.

### Important testing context for the ASM rewrite

After rewriting `fujibus_disk_c.c` to assembly, `*FHOST` initially failed even though it had previously worked with the C version.

Known-good request from the old C path:

- device `0xFE`
- command `0x05` (`ResolvePath`)
- payload bytes:
  - `01 06 00 68 6f 73 74 3a 2f 00 00`

This corresponds to:

- version `1`
- base URI length `6`
- base URI `host:/`
- arg length `0`

### What was observed during testing

With the first ASM version, FujiNet logged:

- `invalid FujiBus frame (response), dropped`

To debug that, raw-frame logging was added to:

- `fujinet-nio/src/lib/fujibus_transport.cpp`

That showed the BBC was sending:

- `c0 c0`

which is an empty SLIP frame.

### Root cause of the first ASM bug

The bug was in `send_small_packet` inside `src/fujibus_disk.s`.

`calc_checksum` destroys `aws_tmp02/03` while iterating through the packet buffer.  
Those bytes were also being used as the packet length passed into `_fujibus_slip_encode`.

So the flow became:

1. packet length prepared in `aws_tmp02/03`
2. checksum routine consumed and zeroed those bytes
3. `_fujibus_slip_encode` was called with length `0`
4. output became only `SLIP_END SLIP_END`, i.e. `c0 c0`

This has now been fixed by preserving and restoring `aws_tmp02/03` around the checksum call.

### Current state at handoff

- `fn-rom` builds successfully after the `fujibus_disk` assembly rewrite
- the drive-map fixes in this document are still not applied
- the assembly rewrite still needs runtime validation by re-testing commands such as `*FHOST`
- FujiNet-side raw-frame logging is currently present to help debug malformed BBC packets

### If continuing from here

Suggested next steps:

1. re-test `*FHOST` and confirm the ASM path now sends a valid FujiBus frame
2. if there is still a packet issue, inspect the raw SLIP frame now logged by FujiNet
3. once the `fujibus_disk.s` rewrite is proven stable, continue porting other large C objects to ASM
4. after enough ROM is recovered, return to the drive-map fixes described below

### Other useful context

The main deferred drive-map problems are:

- `*FMOUNT` stores the wrong byte in `fuji_drive_disk_map`
- disk I/O currently does not consistently treat `fuji_drive_disk_map[current_drv]` as the authoritative slot source
- an unmapped BBC drive can therefore still appear to show a mounted disk

The rest of this document captures those mapping issues and the intended fix plan.

## Purpose

This document captures the drive mapping issues discovered in `fn-rom` and the changes we want to make later, once ROM space has been recovered from the C-to-ASM rewrite work.

The goal is to make BBC drive selection behave like a real floppy setup:

- an unmounted BBC drive should not silently show a disk
- `*FMOUNT <slot> <drive>` should store the correct mapping
- all disk I/O should go through the BBC drive -> FujiNet slot map

## Relevant state

- `fuji_drive_disk_map` at `$10DB` to `$10DE`
- `FUJI_DRIVE_DISK_MAP` in C
- `current_drv` at `$CD`
- `fuji_disk_slot` / `FUJI_DISK_SLOT` at `$10ED`

Intended meaning:

- `current_drv` = currently selected BBC drive `0-3`
- `fuji_drive_disk_map[current_drv]` = mapped FujiNet mount slot for that BBC drive
- `$FF` in the map = no disk mounted in that BBC drive
- `fuji_disk_slot` = working slot value used for a specific FujiBus disk request

## Expected behavior

After FujiNet initialization:

- `fuji_drive_disk_map` should be `FF FF FF FF`
- `*CAT:0` should fail because nothing is mounted to BBC drive 0
- no disk catalog should be shown until `*FMOUNT` maps a FujiNet slot to that BBC drive

After `*FMOUNT 1 0`:

- BBC drive 0 should map to FujiNet slot 1
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

In `src/commands/cmd_fmount_c.c` the code currently does:

```c
aws_tmp08 = FUJI_DISK_SLOT;
```

`FUJI_DISK_SLOT` is a pointer macro to address `$10ED`, not the slot byte value.  
With cc65 this ends up storing the low byte of the address, which is `$ED`.

Then `src/fuji_mount.s` writes `aws_tmp08` into `fuji_drive_disk_map[current_drv]`.

That explains why the map becomes:

- `ED FF FF FF`

instead of:

- `01 FF FF FF`

for `*FMOUNT 1 0`.

### 3. Disk reads and writes bypass the drive map

The serial FujiBus disk path currently reads the slot directly from `FUJI_DISK_SLOT`, not from `fuji_drive_disk_map[current_drv]`.

Files:

- `src/fujibus_disk_c.c`
- `src/fuji_serial.s`
- `src/fuji_fs.s`

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

Current broken code:

- `src/commands/cmd_fmount_c.c`
- `src/fuji_mount.s`

Wanted change:

- stop assigning `aws_tmp08 = FUJI_DISK_SLOT`
- either:
  - change the C to write the slot byte value, e.g. `aws_tmp08 = *FUJI_DISK_SLOT`, or
  - better, stop depending on `aws_tmp08` here and have `fuji_mount_disk` read `fuji_disk_slot` directly

Preferred direction:

- make `fuji_mount_disk` record `fuji_disk_slot`
- remove the extra temporary handoff through `aws_tmp08`

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

This is preferable to duplicating the logic in multiple C functions.

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

Given ROM pressure, prefer reusing an existing error path instead of adding a new inline string.

## ROM-space notes

During investigation, straightforward fixes were prototyped but caused ROM overflow.

The expensive versions were:

- adding new inline error strings
- duplicating mapping checks in multiple places
- moving too much logic into C helpers

For the later implementation, we should prefer:

- one small assembly helper to resolve `current_drv -> fuji_disk_slot`
- reuse of existing error handlers
- avoiding new C logic where a few assembly instructions are enough

## Suggested implementation order after ROM reduction

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
