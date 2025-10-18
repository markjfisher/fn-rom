# Phase 7: OSFILE Table Structure Fix

## Critical Issue Discovered

During implementation of Phase 7 (remaining OSFILE operations), we discovered a **critical naming and structural mismatch** between our OSFILE dispatch table and MMFS.

## The Problem

Our file naming scheme used **table position numbers** (osfile1, osfile2, etc.) but MMFS uses **OSFILE A-register value numbers**. This caused massive confusion because:

1. The table positions don't match the OSFILE A values (due to A=$FF being position 0)
2. Our file names suggested operations that didn't match what they actually did
3. Operations were mapped to wrong table positions

### Original (WRONG) Structure

| Table Position | Our Old Filename | What It Should Be (MMFS) |
|----------------|------------------|--------------------------|
| 0 | osfileFF_loadfiletoaddr ✓ | osfileFF_loadfiletoaddr |
| 1 | osfile0_savememblock ✓ | osfile0_savememblock |
| 2 | osfile1_savefile ❌ | osfile1_updatecat |
| 3 | osfile2_deletefile ❌ | osfile2_wrloadaddr |
| 4 | osfile3_createfile ❌ | osfile3_wrexecaddr |
| 5 | osfile4_writeloadaddr ❌ | osfile4_wrattribs |
| 6 | osfile5_writeexecaddr ❌ | osfile5_rdcatinfo |
| 7 | osfile6_writefileattr ❌ | osfile6_delfile |

## The Fix

We renamed all files and updated the dispatch table to match MMFS exactly:

### Corrected Structure (Matches MMFS)

| Table Position | OSFILE A Value | Function Name | Operation |
|----------------|----------------|---------------|-----------|
| 0 | $FF | osfileFF_loadfiletoaddr | Load file to address |
| 1 | $00 | osfile0_savememblock | Save memory block |
| 2 | $01 | osfile1_updatecat | Update catalog (load/exec addresses) |
| 3 | $02 | osfile2_wrloadaddr | Write load address only |
| 4 | $03 | osfile3_wrexecaddr | Write exec address only |
| 5 | $04 | osfile4_wrattribs | Write file attributes (locked status) |
| 6 | $05 | osfile5_rdcatinfo | Read catalog information |
| 7 | $06 | osfile6_delfile | Delete file |

## Files Changed

### Renamed Files
- `osfile1_savefile.s` → `osfile1_updatecat.s`
- `osfile2_deletefile.s` → `osfile6_delfile.s`

### Deleted Stub Files
- `osfile3_createfile.s` (removed - not an OSFILE operation)
- `osfile4_writeloadaddr.s` (removed - wrong naming)
- `osfile5_writeexecaddr.s` (removed - wrong naming)
- `osfile6_writefileattr.s` (removed - wrong naming)

### New Implementation Files
- `osfile2_wrloadaddr.s` - OSFILE A=2 (Write load address)
- `osfile3_wrexecaddr.s` - OSFILE A=3 (Write exec address)
- `osfile4_wrattribs.s` - OSFILE A=4 (Write file attributes/locked status)
- `osfile5_rdcatinfo.s` - OSFILE A=5 (Read catalog information)

### Updated Files
- `filev_entry.s` - Updated imports and dispatch table to match MMFS naming

## Implementation Details

All new functions follow MMFS implementation exactly:

### osfile2_wrloadaddr (A=2)
- Find file in catalog
- Update load address
- Save catalog
- Return A=1

### osfile3_wrexecaddr (A=3)
- Find file in catalog
- Update exec address
- Save catalog
- Return A=1

### osfile4_wrattribs (A=4)
- Find file in catalog
- Check file not open
- Update lock bit in catalog (uses EOR/AND/EOR pattern to preserve other bits)
- Save catalog
- Return A=1

### osfile5_rdcatinfo (A=5)
- Find file in catalog
- Read file attributes to parameter block
- Return A=1 (file found)

## Key Learnings

1. **Always use MMFS naming conventions** - The function names use the OSFILE A-register value, NOT the table position
2. **Dispatch table is offset by 1** - Because A=$FF maps to position 0, all other operations are shifted
3. **File operations vs. catalog operations** - Some operations (A=2,3,4) only modify catalog, while others (A=0,6) also affect disk data
4. **Lock bit manipulation** - The EOR/AND/EOR pattern is used to toggle specific bits while preserving others

## Testing Required

Need to create comprehensive test for all OSFILE operations:
- Save memory block (A=0) - Already tested
- Update catalog (A=1) - Implemented, needs test
- Write load address (A=2) - New, needs test
- Write exec address (A=3) - New, needs test
- Write attributes (A=4) - New, needs test
- Read catalog info (A=5) - New, needs test
- Delete file (A=6) - Already tested in Phase 6

## Build Status

✅ Clean build successful with all correctly named files

