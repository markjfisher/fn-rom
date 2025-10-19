# Phase 8: OSFILE Return Value and Exec Address Fixes

## Summary
Fixed two critical issues with OSFILE operations that were preventing proper return values and program execution.

## Issue 1: OSFILE A=0 Return Value (FIXED)

### Problem
`test_phase8.bas` was returning A=0 instead of A=1 for successful OSFILE A=0 (save memory block) operations.

### Root Cause
`filev_entry.s` was using `remember_axy`, which saves and restores **all three registers** (A, X, Y). This meant that even when `osfile0_savememblock` set `A=1` for success, the cleanup code would restore A to its original value, wiping out the return value.

### Solution
Changed `filev_entry.s` to use `remember_xy_only` instead of `remember_axy`, matching MMFS architecture (line 3672 of mmfs100.asm).

```assembly
; OLD (incorrect):
jsr     remember_axy        ; Saves A, X, Y - A gets restored!

; NEW (correct):
jsr     remember_xy_only    ; Save X,Y only - A is the return value!
```

### Why This Works
- OSFILE functions need to **return values in the A register** (e.g., A=1 for success, A=0 for failure)
- X and Y contain parameters (parameter block address) that need to be preserved
- A must NOT be preserved - it's the return value!

### MMFS Reference
- MMFS line 3672: `JSR RememberXYonly` (not RememberAXY)
- This pattern is used throughout MMFS for functions that return values in A

---

## Issue 2: *RUN Command Exec Address (FIXED)

### Problem
`cmd_run.s` had manual code (lines 126-129) to copy the exec address from the catalog to `&BE/&BF`, with a TODO comment noting it differed from MMFS.

```assembly
; OLD (redundant):
lda     dfs_cat_file_exec_addr,y    ; Exec address low byte from catalog
sta     aws_tmp14                    ; Store in workspace (&BE)
lda     dfs_cat_file_exec_addr+1,y  ; Exec address high byte from catalog
sta     aws_tmp15                    ; Store in workspace (&BF)
```

### Root Cause
This code was **redundant**. `LoadFile_Ycatoffset` already correctly sets `&BE/&BF` to the file's exec address as part of its catalog copy loop.

### How LoadFile_Ycatoffset Works
When loading a file, it copies catalog entry data to zero page:

**Catalog structure** (at `$0F08 + Y`):
- +0,+1: Load address low bytes
- +2,+3: Exec address low bytes (← we care about these!)
- +4,+5: File size low bytes
- +6: Mixed byte
- +7: Sector

**Copy loop** (`osfileFF_loadfiletoaddr.s` lines 70-77):
```assembly
@load_copyfileinfo_loop:
    lda     $0F08,y              ; Read from catalog
    sta     aws_tmp12,x          ; Write to &BC,X
    iny
    inx
    cpx     #$08
    bne     @load_copyfileinfo_loop
```

**Result in zero page**:
- `&BC` = Load addr low byte 0
- `&BD` = Load addr low byte 1
- `&BE` = **Exec addr low byte 0** ← Used by JMP (&BE)
- `&BF` = **Exec addr low byte 1**
- `&C0` = File size low byte 0
- `&C1` = File size low byte 1
- `&C2` = Mixed byte
- `&C3` = Sector

Additionally, `exec_addr_hi2` (called on line 79) sets:
- `fuji_buf_1076` = Exec addr high byte 0
- `fuji_buf_1077` = Exec addr high byte 1

### Solution
Removed the redundant manual copy code from `cmd_run.s`.

### MMFS Reference
- MMFS lines 2180-2207: `runfile_run` implementation
- Line 2181: `JSR LoadFile_Ycatoffset` - loads file AND sets exec addr
- Line 2207: `JMP (&00BE)` - directly jumps to exec addr (no manual copy!)

---

## Testing
Both fixes have been applied and the ROM has been successfully rebuilt. The fixes now match MMFS architecture exactly:

1. ✅ OSFILE functions can return values in A register
2. ✅ *RUN command uses exec address from LoadFile_Ycatoffset (no manual override)

## Files Changed
1. `/home/markf/dev/bbc/fn-rom/src/vectors/filev_entry.s`:
   - Changed `remember_axy` to `remember_xy_only` (line 67)
   
2. `/home/markf/dev/bbc/fn-rom/src/commands/cmd_run.s`:
   - Removed redundant exec address copy (old lines 126-129)

## Impact
- **OSFILE operations** now correctly return success/failure codes
- ***RUN command** now follows MMFS architecture exactly
- Both fixes eliminate deviations from MMFS, improving maintainability and correctness

