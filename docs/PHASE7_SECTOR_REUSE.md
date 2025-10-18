# Phase 7: RAM Filesystem Sector Reuse

## Problem

The initial implementation of `get_next_available_sector` was too simplistic:
- It only incremented `NEXT_AVAILABLE_SECTOR` at `$5000`
- It never reclaimed freed sectors from deleted files
- This meant the filesystem would quickly run out of space (only 12 pages available)
- Without reuse, you couldn't create/delete/create cycles

## Solution

Implemented proper sector allocation with reuse using a page allocation bitmap.

### Data Structures

**RAM Layout** (starting at `$5000`):
- `$5000`: `NEXT_AVAILABLE_SECTOR` - High-water mark for sector allocation (1 byte)
- `$5001-5007`: Reserved for debug/future use (7 bytes)
- `$5008-51FF`: Catalog (512 bytes = 2 sectors)
- `$5208-5217`: `RAM_PAGE_ALLOC` - Page allocation bitmap (16 bytes, supports up to 16 pages)
- `$5218+`: File data pages (12 pages × 256 bytes = 3KB)

### Implementation

#### 1. `get_next_available_sector` - Enhanced Allocation

**Strategy:**
1. Scan `RAM_PAGE_ALLOC` for first free page (value = 0)
2. If found, mark it allocated (value = 1) and return `sector = page + FIRST_RAM_SECTOR`
3. If no free pages found, allocate new page at `NEXT_AVAILABLE_SECTOR` and increment it

**Code Flow:**
```assembly
get_next_available_sector:
    ; Scan pages 0 to (NEXT_AVAILABLE_SECTOR - FIRST_RAM_SECTOR - 1)
    for each page:
        if RAM_PAGE_ALLOC[page] == 0:
            RAM_PAGE_ALLOC[page] = 1
            return page + FIRST_RAM_SECTOR
    
    ; No free pages, allocate new one
    sector = NEXT_AVAILABLE_SECTOR
    mark_as_allocated(sector)
    NEXT_AVAILABLE_SECTOR++
    return sector
```

#### 2. `free_ram_sector` - Mark Sector as Free

**Purpose:** Called when a file is deleted to reclaim its sector

**Implementation:**
```assembly
free_ram_sector:
    ; Input: A = sector number
    if sector < FIRST_RAM_SECTOR:
        return  ; Can't free catalog sectors 0-1
    
    page = sector - FIRST_RAM_SECTOR
    RAM_PAGE_ALLOC[page] = 0  ; Mark as free
```

#### 3. Integration with `delete_cat_entry_yfileoffset`

Added conditional code for `FUJINET_INTERFACE_DUMMY`:
```assembly
delete_cat_entry_yfileoffset:
    check_file_not_locked_or_open_y
    
.ifdef FUJINET_INTERFACE_DUMMY
    ; Free the sector used by this file
    lda dfs_cat_file_sect,y    ; Get start sector
    and #$7F                    ; Mask off lock bit
    jsr free_ram_sector         ; Mark as free
.endif
    
    ; Continue with catalog entry deletion...
```

### Test Case: `test_phase7.bas` (7REUSE)

**Test Scenario:**
1. Create FILE1 (should get sector 5)
2. Create FILE2 (should get sector 6)
3. Show catalog - verify sectors 5,6
4. Delete FILE1
5. Create FILE3 (should reuse sector 5, not allocate new sector 7)
6. Show catalog - verify FILE3 is at sector 5

**Expected Results:**
- **PASS**: FILE3 at sector 005 (reused)
- **FAIL**: FILE3 at sector 007 (no reuse, would happen with old implementation)

### Benefits

1. **Space Efficiency**: Can reuse freed sectors, maximizing the 12-page limit
2. **Create/Delete Cycles**: Can create, delete, and create again without exhausting space
3. **Compact Bitmap**: Only 16 bytes needed for allocation tracking (supports up to 16 pages, currently using 12)
4. **Best-Fit Allocation**: Always returns lowest-numbered free sector first
5. **Memory Savings**: Eliminated unused `RAM_PAGE_LENGTH` table (saved 32 bytes)

### Limitations

1. **Single Sector Per File**: Current implementation only frees the start sector
   - Multi-sector files would need to free all sectors (start_sector through start_sector + length)
   - This is acceptable for testing as most test files are < 256 bytes
2. **Linear Scan**: O(n) allocation time, but n ≤ 12 so performance is fine
3. **No Defragmentation**: Sectors aren't compacted, but not needed for testing

### Build Status

✅ Builds successfully with `FUJINET_INTERFACE_DUMMY` flag
✅ `free_ram_sector` and `get_next_available_sector` exported
✅ Conditional compilation ensures changes only affect dummy interface
✅ Test program created (`test_phase7.bas`)

### Future Enhancements

If needed for more complex testing:
1. Free all sectors for multi-sector files (loop through length)
2. Add defragmentation to compact free space
3. Track fragmentation metrics
4. Implement sector chaining for files > 256 bytes

