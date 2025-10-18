# FujiNet ROM Documentation

This directory contains technical documentation, test plans, and analysis documents for the FujiNet ROM development.

## Documents

### Test Plans

- **[PHASE5_TEST_PLAN.md](PHASE5_TEST_PLAN.md)** - Comprehensive test plan for Phase 5 (Random Access Write)
  - Tests OPENUP, PTR#, overwrite, and append operations
  - Includes expected results, debugging strategies, and success criteria
  - **Status**: Ready for testing

- **[phase5_summary.md](phase5_summary.md)** - Quick reference for Phase 5 test
  - What was created (BASIC test, breakpoints, docs)
  - Why it's critical
  - Expected outcomes and next steps

### Technical Analysis

- **[fuji_dummy_analysis.md](fuji_dummy_analysis.md)** - Analysis of fuji_dummy.s refactoring
  - Issues found (misleading comments, poor encapsulation)
  - Fixes applied (renamed constants, created proper API)
  - Memory layout clarification

## Test Files

Test BASIC programs are located in `../bas/`:
- `test_phase1.bas` (1CREAT) - File creation
- `test_phase2.bas` (2TESTWR) - BPUT data writing
- `test_phase3.bas` (3TESTWR) - Complete write/read cycle
- `test_phase4.bas` (4MULTI) - Multi-file interleaved I/O
- `test_phase5.bas` (5RANDOM) - Random access write (overwrite + append)

## Breakpoint Files

Breakpoint CSV files for emulator debugging:
- `../mmfs-breakpoints.csv` - MMFS ROM reference breakpoints
- `../2write-bp.csv` - Phase 2 write path
- `../4multi-bp.csv` - Phase 4 multi-file
- `../5random-bp.csv` - Phase 5 random access

Usage:
```bash
python3 set-breakpoints.py -i <breakpoint-file.csv>
```

## Testing Progress

### ✅ Completed Phases
- **Phase 1**: File creation - ✅ PASSED
- **Phase 2**: BPUT data writing - ✅ PASSED
- **Phase 3**: Complete write/read cycle - 🔄 In Progress
- **Phase 4**: Multi-file interleaved I/O - 🔄 In Progress

### 🔄 Current Phase
- **Phase 5**: Random access write - 📝 Ready for testing

### 📋 Future Phases
- **Phase 6**: File deletion
- **Phase 7**: Attribute changes (load/exec/locked)
- **Phase 8**: Error handling
- **Phase 9**: Edge cases and stress testing

## RAM Filesystem Layout

```
$5000      - next_available_sector (1 byte)
$5001-5007 - Reserved for debug markers (7 bytes)
$5008-51FF - Catalog (512 bytes = 2 sectors)
$5200-523F - Page allocation table (32 bytes)
$5220-523F - Page length table (32 bytes)
$5240-5DFF - File data pages (12 × 256 bytes = 3KB)
```

**Total RAM usage**: $E00 (3.5KB)

### Pre-loaded Files
- **TEST** - Sector 2 (page 0 at $5248)
- **WORLD** - Sector 3 (page 1 at $5348)
- **HELLO** - Sector 4 (page 2 at $5448)
- **New files** - Start at sector 5+ (pages 3+)

## Quick Start

1. **Build the ROM**:
   ```bash
   cd /home/markf/dev/bbc/fn-rom
   make
   ```

2. **Run tests**:
   ```bash
   # Convert BASIC to SSD
   ./bas2ssd.sh bas/test_phase5.bas 5RANDOM test_disk.ssd
   
   # Set breakpoints (optional)
   python3 set-breakpoints.py -i 5random-bp.csv
   
   # In emulator:
   *FUJI
   CHAIN "5RANDOM"
   ```

3. **Inspect results**:
   - Check console output for PASS/FAIL
   - Examine RAM disk memory at $5000+
   - Check catalog at $0E00-$0FFF

## Key Design Decisions

### Dummy Interface vs Real FujiNet
The dummy interface (`FUJINET_INTERFACE_DUMMY`) uses:
- **Zero-length file creation** - Files start at 0 bytes (RAM limited)
- **Tracked sector allocation** - `get_next_available_sector()` function
- **Sequential sectors** - No gap-finding needed

Real FujiNet will use:
- **64-sector pre-allocation** - Standard MMFS behavior ($4000 bytes)
- **Gap-finding algorithm** - Reuses freed sectors efficiently
- **Network-based storage** - Not RAM-limited

### Architectural Principles
1. **MMFS Compatibility** - Match MMFS behavior exactly
2. **Encapsulation** - Core ROM doesn't know dummy implementation details
3. **Isolation via ifdef** - Dummy-specific code wrapped in `#ifdef`
4. **Proper APIs** - Functions, not direct memory manipulation

## Contributing

When adding new documentation:
1. Place in this `docs/` directory
2. Update this README with links and descriptions
3. Use clear, descriptive filenames
4. Include expected results and success criteria

