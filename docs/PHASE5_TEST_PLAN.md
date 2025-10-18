# Phase 5: Random Access Write Test Plan

## Objective
Test random access file operations including:
1. **Overwriting existing data** at specific positions
2. **Appending data** to existing files
3. **Multiple file handles** to ensure correct file/sector isolation

## Why This Test Is Critical

### 1. **Catches Sector Confusion Bugs**
- Opening 2 files simultaneously exposes any issues with channel isolation
- Similar to Phase 4's discovery of FILE2 getting sector `$45` instead of `$06`
- Ensures each file handle maintains its own PTR, buffer, and sector context

### 2. **Tests Overwrite Logic**
- Overwrites require seeking to a specific position
- Must read buffer from disk if not already in memory
- Must write buffer back to same sector (not create new file!)
- Tests that PTR# correctly positions within file

### 3. **Tests Append Logic** 
- Appending to existing files tests file extension
- Must preserve existing data while adding new bytes
- Ensures catalog size is updated correctly
- Tests that EOF detection works properly

### 4. **RAM Disk Verification**
- After test, we can inspect RAM disk at `$5000+`
- FILE1 should be at sector 5 → page 3 → `$5548`
- FILE2 should be at sector 6 → page 4 → `$5648`
- Visual inspection confirms data isn't corrupted or misplaced

## Test Sequence

### Phase A: Initial File Creation
1. **OPENOUT("FILE1")** → Creates new file at sector 5
2. Write `"ABC"` (3 bytes)
3. **OPENOUT("FILE2")** → Creates new file at sector 6
4. Write `"XYZ"` (3 bytes)
5. **CLOSE** both files
6. Verify with `*INFO` → Both should show 3 bytes

### Phase B: Random Access Modification
7. **OPENUP("FILE1")** → Open for read/write
8. **OPENUP("FILE2")** → Open for read/write
9. FILE1: `BGET#H1%` (read 'A', PTR now at 1)
10. FILE1: `BPUT#H1%,81` (write 'Q' at position 1, overwriting 'B')
11. FILE2: `BGET#H2%` (read 'X', PTR now at 1)
12. FILE2: `BPUT#H2%,80` (write 'P' at position 1, overwriting 'Y')
13. FILE1: `PTR#H1%=3` (seek to end)
14. FILE1: `BPUT#H1%,33` (append '!', extends to 4 bytes)
15. FILE2: `PTR#H2%=3` (seek to end)
16. FILE2: `BPUT#H2%,64` (append '@', extends to 4 bytes)
17. **CLOSE** both files

### Phase C: Verification
18. Verify with `*INFO` → Both should show 4 bytes now
19. **OPENIN("FILE1")**, read 4 bytes
20. Verify content = `"AQC!"` (A unchanged, B→Q, C unchanged, ! appended)
21. **OPENIN("FILE2")**, read 4 bytes
22. Verify content = `"XPZ@"` (X unchanged, Y→P, Z unchanged, @ appended)
23. **CLOSE** both files

## Expected Results

### Catalog State
```
$.FILE1    000000 FFFFFF 000004 005  (4 bytes at sector 5)
$.FILE2    000000 FFFFFF 000004 006  (4 bytes at sector 6)
```

### RAM Disk Contents
```
$5548: 41 51 43 21  ('A' 'Q' 'C' '!')  ← FILE1 at sector 5
$5648: 58 50 5A 40  ('X' 'P' 'Z' '@')  ← FILE2 at sector 6
```

### Success Criteria
✅ Both files correctly overwritten at position 1  
✅ Both files correctly extended by 1 byte  
✅ No sector confusion between files  
✅ Catalog shows correct sizes (4 bytes each)  
✅ Data reads back exactly as expected  
✅ RAM disk inspection confirms data at correct sectors  

## What Can Go Wrong

### Potential Bugs to Catch:

1. **Sector Confusion**
   - FILE2 writes might go to FILE1's sector
   - Similar to previous `$45` bug

2. **Overwrite Creates New File**
   - Instead of updating existing sector, creates new catalog entry
   - Would show duplicate files in `*CAT`

3. **Append Corruption**
   - Append might overwrite existing data
   - Or append to wrong file's sector

4. **PTR# Not Working**
   - Seeking might not position correctly
   - Could read/write at wrong offset

5. **Buffer Flush Issues**
   - Modified buffer not written to disk
   - Old data read back instead of new

6. **Channel Isolation Failure**
   - H1% operations affect H2%'s buffer/PTR
   - State leaks between handles

## Debugging

### Breakpoints (5random-bp.csv)
Key functions to trace:
- `findv_openup` - OPENUP entry point
- `argsv_entry` - PTR# operations
- `bp_entry` / `bg_entry` - BPUT/BGET
- `channel_buffer_to_disk_yintch` - Buffer writes
- `fuji_write_block_data` - Actual RAM disk writes

### Memory Inspection Points
1. **After Phase A**: Check `$5548` and `$5648` for "ABC" and "XYZ"
2. **After Phase B**: Check same locations for "AQC!" and "XPZ@"
3. **Catalog at $0E00**: Verify file sizes change from $0003 to $0004

### Debug Markers ($5000-$5007)
These may be used during execution for tracing:
- `$5000` - next_available_sector (should stay at 7 after both files created)
- `$5001-$5007` - Available for debug output

## Run Instructions

```bash
# Generate the BASIC program as a BBC Micro file
cd /home/markf/dev/bbc/fn-rom
./bas2ssd.sh bas/test_phase5.bas 5RANDOM test_disk.ssd

# Set breakpoints in emulator
python3 set-breakpoints.py -i 5random-bp.csv

# Run in emulator (b2)
# 1. Boot with FujiNet ROM
# 2. *FUJI (initialize RAM filesystem)
# 3. CHAIN "5RANDOM" or *RUN 5RANDOM
# 4. Watch output for PASS/FAIL messages
```

## Success Message
```
===================================
Phase 5 Complete!
ALL TESTS PASSED
===================================
```

## Next Steps After Phase 5

If Phase 5 passes, we'll have proven:
- ✅ File creation works
- ✅ Single file write/read works
- ✅ Multi-file interleaved I/O works
- ✅ Random access positioning works
- ✅ Overwrite existing data works
- ✅ Append to existing files works

**Then we can move to:**
- Phase 6: File deletion
- Phase 7: Directory operations
- Phase 8: Error handling (disk full, file not found, etc.)
- Phase 9: Edge cases (EOF, empty files, max catalog)

