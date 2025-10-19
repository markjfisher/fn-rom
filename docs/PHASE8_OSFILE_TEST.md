# Phase 8: Comprehensive OSFILE Operations Test

## Test Program: `test_phase8.bas` (8OSFILE)

A comprehensive test that exercises all implemented OSFILE operations in sequence to verify correct functionality.

## Operations Tested

### 1. OSFILE A=0 - Save Memory Block
- Creates a new file `TESTF1`
- Saves 16 bytes from memory (&3000-&300F)
- Sets load address = &1900
- Sets exec address = &1900
- **Validates**: File creation with data

### 2. OSFILE A=5 - Read Catalog Information
- Reads file attributes from catalog
- **Validates**: Load address = &1900, Length = 16 bytes

### 3. OSFILE A=1 - Update Catalog Entry
- Changes load address to &2000
- Changes exec address to &2100
- **Validates**: Catalog updates both addresses

### 4. OSFILE A=5 - Verify Update
- Re-reads catalog to confirm changes persisted
- **Validates**: Load = &2000, Exec = &2100

### 5. OSFILE A=2 - Write Load Address Only
- Changes only load address to &3000
- Leaves exec address unchanged
- **Validates**: Selective address update

### 6. OSFILE A=3 - Write Exec Address Only
- Changes only exec address to &3100
- Leaves load address unchanged
- **Validates**: Selective address update

### 7. OSFILE A=5 - Verify Both Changes
- Confirms both A=2 and A=3 worked correctly
- **Validates**: Load = &3000, Exec = &3100

### 8. OSFILE A=4 - Lock File
- Sets locked bit in file attributes (P%?14=8)
- **Validates**: File can be locked

### 9. Visual Verification
- Uses `*INFO TESTF1` to show locked status
- Should display 'L' flag
- **Validates**: Lock status visible in catalog

### 10. Delete Locked File Test
- Attempts to delete locked file (should fail)
- Uses `ON ERROR` to catch expected error
- **Validates**: Lock protection works

### 11. OSFILE A=4 - Unlock File
- Clears locked bit in file attributes (P%?14=0)
- **Validates**: File can be unlocked

### 12. OSFILE A=6 - Delete File
- Deletes unlocked file using OSFILE
- **Validates**: File deletion via OSFILE

### 13. Verify Deletion
- Attempts to open file (should return handle = 0)
- **Validates**: File is actually gone from catalog

### 14. Final Catalog Display
- Shows final catalog state with `*INFO *`
- **Validates**: Clean state, TESTF1 removed

## Test Flow

```
Create File (A=0)
    ↓
Read Info (A=5) → Verify initial state
    ↓
Update Catalog (A=1) → Change load & exec
    ↓
Read Info (A=5) → Verify update
    ↓
Write Load (A=2) → Change load only
    ↓
Write Exec (A=3) → Change exec only
    ↓
Read Info (A=5) → Verify both changes
    ↓
Lock File (A=4) → Set locked bit
    ↓
*INFO → Visual verification
    ↓
Try Delete → Should FAIL (locked)
    ↓
Unlock File (A=4) → Clear locked bit
    ↓
Delete File (A=6) → Should SUCCEED
    ↓
Verify Gone → OPENIN returns 0
    ↓
*INFO * → Show final state
```

## OSFILE Parameter Block Layout

The test uses a 18-byte parameter block at `P%`:

```
Offset  Size  Description
------  ----  -----------
0-1     2     Pointer to filename (terminated with CR)
2-5     4     Load address (32-bit)
6-9     4     Exec address (32-bit)
10-13   4     Start address (for A=0) / File length (for A=5)
14-17   4     End address (for A=0) / File attributes (for A=4,5)
```

## Expected Results

**Success Criteria:**
- ✅ File created with correct size
- ✅ Catalog reads return correct values
- ✅ Load/exec addresses update independently
- ✅ Lock bit prevents deletion
- ✅ Unlock allows deletion
- ✅ File actually removed from catalog
- ✅ Final message: "*** ALL OSFILE TESTS PASSED ***"

**Failure Modes:**
- ❌ Wrong load/exec addresses after update
- ❌ Locked file can be deleted
- ❌ File still exists after deletion
- ❌ Any operation returns wrong values

## Implementation Coverage

| OSFILE A | Operation | Implementation | Test Coverage |
|----------|-----------|----------------|---------------|
| $FF | Load file | `osfileFF_loadfiletoaddr` | Via *LOAD command |
| $00 | Save memory | `osfile0_savememblock` | ✅ Step 1 |
| $01 | Update catalog | `osfile1_updatecat` | ✅ Steps 3-4 |
| $02 | Write load addr | `osfile2_wrloadaddr` | ✅ Steps 5,7 |
| $03 | Write exec addr | `osfile3_wrexecaddr` | ✅ Steps 6-7 |
| $04 | Write attributes | `osfile4_wrattribs` | ✅ Steps 8,11 |
| $05 | Read catalog info | `osfile5_rdcatinfo` | ✅ Steps 2,4,7 |
| $06 | Delete file | `osfile6_delfile` | ✅ Step 12 |

## Notes

1. **Error Handling**: Test uses `ON ERROR` to verify lock protection works
2. **Interactive Pause**: Step 9 waits for keypress to allow visual inspection
3. **Memory Usage**: Uses &3000-&300F for test data (safe area)
4. **Parameter Block**: Allocated at DIM P% 17 (18 bytes)

## Related Files

- Implementation: `/src/vectors/filev/osfile_functions.s`
- Test: `/bas/test_phase8.bas`
- Documentation: This file

## Build Status

✅ Test created and ready for execution
✅ All OSFILE operations implemented
✅ Comprehensive coverage of operations

