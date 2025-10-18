# Phase 5 Test: Random Access Write

## What Was Created

### 1. bas/test_phase5.bas (5RANDOM)
**Comprehensive random access test with 14 steps:**

**Phase A: Initial Creation**
- Create FILE1 with "ABC" (3 bytes)
- Create FILE2 with "XYZ" (3 bytes)
- Close both files

**Phase B: Random Access Modifications**
- OPENUP both files for read/write access
- FILE1: Read 'A', overwrite 'B'→'Q' at position 1
- FILE2: Read 'X', overwrite 'Y'→'P' at position 1
- FILE1: Seek to end (PTR#=3), append '!'
- FILE2: Seek to end (PTR#=3), append '@'
- Close both files

**Phase C: Verification**
- Reopen both files for reading
- Verify FILE1 = "AQC!" (4 bytes)
- Verify FILE2 = "XPZ@" (4 bytes)
- Close both files

### 2. 5random-bp.csv
Breakpoints for debugging random access operations:
- OPENUP entry point
- PTR# operations (OSARGS)
- BPUT/BGET entry points
- Buffer management (read/write to disk)
- File close operations

### 3. docs/PHASE5_TEST_PLAN.md
Detailed test plan document covering:
- Test objectives and rationale
- Why this test is critical (catches sector confusion, tests overwrite/append)
- Expected RAM disk layout
- Success criteria
- Potential bugs to catch
- Debug strategies

## Why Phase 5 Is Critical

### Tests New Functionality
1. **OPENUP** - Opens file for both read and write
2. **PTR#** - Seeks to specific position in file
3. **Overwrite** - Modifies existing data in place
4. **Append** - Extends existing file

### Catches Critical Bugs
- **Sector isolation**: Ensures FILE1 and FILE2 don't interfere
- **Buffer management**: Ensures correct buffer loaded/saved
- **Catalog updates**: Ensures file sizes updated correctly
- **Data integrity**: Ensures existing data preserved during modifications

## Expected Outcomes

### Console Output
```
Phase 5: Random Access Write Test
===================================
Step 1: Creating FILE1 with 'ABC'
FILE1 created (3 bytes)
Step 2: Creating FILE2 with 'XYZ'
FILE2 created (3 bytes)
...
Step 12: Reading FILE1 (expect 'AQC!')
FILE1 content: 'AQC!'
FILE1 PASS
Step 13: Reading FILE2 (expect 'XPZ@')
FILE2 content: 'XPZ@'
FILE2 PASS
===================================
Phase 5 Complete!
ALL TESTS PASSED
===================================
```

### RAM Disk Memory
```
$5548: 41 51 43 21  ← FILE1 (A Q C !)
$5648: 58 50 5A 40  ← FILE2 (X P Z @)
```

### Catalog ($0E00)
```
FILE1: 4 bytes at sector 5
FILE2: 4 bytes at sector 6
```

## Running The Test

```bash
# Convert BASIC to BBC disk format
./bas2ssd.sh bas/test_phase5.bas 5RANDOM test_disk.ssd

# Set breakpoints (optional, for debugging)
python3 set-breakpoints.py -i 5random-bp.csv

# In emulator:
*FUJI
CHAIN "5RANDOM"
```

## What's Next After Phase 5

If Phase 5 passes, we have a **production-ready filesystem** for:
✅ File creation
✅ Sequential write/read
✅ Multi-file handling
✅ Random access positioning
✅ Overwriting data
✅ Appending to files

**Future phases:**
- Phase 6: File deletion (*DELETE)
- Phase 7: Attribute changes (load/exec/locked)
- Phase 8: Error handling
- Phase 9: Edge cases and stress testing

