# FINDV/BGETV Test Programs

This folder contains test programs to verify the FINDV and BGETV functionality of the FujiNet ROM.

## Test Programs

### 1. `basic_test.bas` (BASIC_T)
- **Purpose**: Simple test that just tries to open the HELLO file
- **What it does**: 
  - Calls OSFIND to open HELLO file for reading
  - Reports the result (handle number or error)
  - Closes the file if opened successfully
- **Expected result**: Should return a file handle (non-zero) if our FINDV_ENTRY is working

### 2. `simple_test.bas` (SIMPLE_)
- **Purpose**: More comprehensive test of file operations
- **What it does**:
  - Opens HELLO file for reading
  - Reads up to 20 bytes using OSBGET
  - Reports each byte read
  - Closes the file
  - Repeats the process with WORLD file
- **Expected result**: Should read bytes from our dummy files and detect EOF

### 3. `test_findv_bgetv.bas` (TEST_FI)
- **Purpose**: Most comprehensive test with proper error handling
- **What it does**:
  - Tests file opening with proper error checking
  - Reads bytes until EOF is detected
  - Tests multiple files (HELLO and WORLD)
  - Provides detailed output for debugging
- **Expected result**: Full test of our filing system implementation

## How to Use

1. **Load the test disk**: Use `test_disk.ssd` in your BBC Micro emulator
2. **Run a test**: 
   ```
   *LOAD BASIC_T
   *RUN
   ```
3. **Check the output**: Look for success/error messages and byte values

## Expected Behavior

### If FINDV_ENTRY is working:
- Files should open successfully and return a handle (non-zero number)
- Files should close without errors

### If BGETV_ENTRY is working:
- Bytes should be read from the dummy files
- EOF should be detected when reaching the end of file
- Byte values should match our dummy data

### If EOF checking is working:
- EOF should be detected at the correct position
- No infinite loops when reading past end of file

## Debugging

If tests fail:
1. Check that the FujiNet ROM is loaded in the emulator
2. Verify that dummy files (HELLO, WORLD) exist in the catalog
3. Look for debug output from our ROM (if FN_DEBUG is enabled)
4. Check that the filing system is properly initialized

## Dummy Data

The tests expect these files to exist:
- **HELLO**: Contains "Hello from FujiNet!" 
- **WORLD**: Contains "World test data"

These are provided by our `fuji_dummy.s` implementation.
