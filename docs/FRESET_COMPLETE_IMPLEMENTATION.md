# *FRESET Command - Complete Implementation

## Overview
The `*FRESET` command has been fully implemented with proper serial communication, response handling, error checking, and status reporting.

## Implementation Summary

### 1. Serial Communication Fixed
- **Problem**: SERPROC was assembling TX bits MSB-first instead of LSB-first
- **Solution**: Changed bit assembly in `serproc.cpp` to use `m_tx_byte |= (bit << m_tx_bit_index)`
- **Result**: 0x70 now transmits correctly (was appearing as 0x0E)

### 2. Checksum Algorithm Corrected
- **Problem**: Checksum didn't match C reference implementation
- **Solution**: Implemented proper carry-propagating checksum: `chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff)`
- **Result**: For `70 FF 00 00 00 00`, checksum is correctly `0x70`

### 3. OS-based Serial I/O
- **Approach**: Uses OSBYTE and OSWRCH instead of direct ACIA manipulation
- **Benefits**:
  - Proper OS integration
  - Buffer management handled by OS
  - Compatible with b2 emulator's SERPROC implementation
  - Same approach as working test.c code

### 4. Response Handling
- **Expected Response**: 'A' (ACK), 'C' (Complete)
- **Timeout**: 50 centiseconds (0.5 seconds) per byte
- **Validation**: Checks each response byte matches expected value

### 5. Status Reporting
- **Method**: Uses OSBYTE 1 (USER_FLAG) to report command result
- **Return Values**:
  - `0` = Success (received 'A' and 'C')
  - `1` = Timeout waiting for response
  - `2` = Invalid ACK byte (not 'A')
  - `3` = Invalid COMPLETE byte (not 'C')

### 6. Code Refactoring
- **New File**: `src/commands/serial_utils.s`
- **Exported Functions**:
  - `setup_serial_19200` - Configure serial port for 19200 baud
  - `restore_output_to_screen` - Restore output to screen/keyboard
  - `read_serial_byte` - Read byte from serial with timeout
  - `calc_checksum` - Calculate FujiNet checksum (reusable)

## Usage

### In BBC BASIC:
```basic
*FRESET
```

### Checking Result:
```basic
X%=USR(&FFF4) AND &FF00 DIV &100 : REM OSBYTE 0 to read user flag
IF X%=0 THEN PRINT "Success" ELSE PRINT "Error: ";X%
```

### In 6502 Assembly:
```asm
jsr cmd_fs_freset
; Check result via OSBYTE 0:
ldx #0
ldy #0
lda #0
jsr OSBYTE
; X now contains result (0 = success)
```

## Protocol Details

### Command Frame (7 bytes):
```
Byte 0: 0x70 (THE_FUJI device ID)
Byte 1: 0xFF (Reset command)
Byte 2-5: 0x00 (unused parameters)
Byte 6: checksum (0x70 for this command)
```

### Response (2 bytes):
```
Byte 0: 'A' (0x41) - ACK
Byte 1: 'C' (0x43) - Complete
```

## Files Modified

### FujiNet ROM:
- `src/commands/cmd_freset.s` - Main command implementation
- `src/commands/serial_utils.s` - NEW: Reusable serial utilities
- `src/commands/cmd_tables.s` - Command table entries

### b2 Emulator:
- `src/beeb/src/serproc.cpp` - Fixed TX bit assembly (LSB-first)
- `src/beeb/include/beeb/serproc.h` - Added `m_tx_bit_index` member
- `src/beeb/src/BBCMicro.cpp` - Added `GetMMFS()` method
- `src/beeb/include/beeb/BBCMicro.h` - GetMMFS() declaration
- `src/b2/BeebThread.cpp` - Use direct GetMMFS() instead of GetUniqueState()
- `src/b2/PTYSerial.cpp` - PTY serial device implementation
- `src/b2/PTYSerial.h` - PTY serial device header
- `src/b2/FujiNetConfig.*` - FujiNet configuration
- `src/b2/FujiNetConfigUI.*` - FujiNet UI
- `src/b2/BeebConfig.h` - Main config structure
- `src/b2/ConfigsUI.cpp` - UI integration

## Testing

### Test with b2 Emulator:
1. Start serial bridge: `./bridge -d /dev/ttyS0 -b 19200 -p /tmp/inject-tty`
2. Start FujiNet firmware
3. Run b2: `b2-debug --config-folder=test`
4. In emulator: `*FRESET`
5. Check serial output shows: `70 FF 00 00 00 00 70`
6. Check response: 'A', 'C' received

### Expected Debug Output:
```
[PTY TX] AddByte: 0x70 ('p') - queue size now: 1
[PTY TX] AddByte: 0xFF ('.') - queue size now: 2
[PTY TX] AddByte: 0x00 ('.') - queue size now: 3
[PTY TX] AddByte: 0x00 ('.') - queue size now: 4
[PTY TX] AddByte: 0x00 ('.') - queue size now: 5
[PTY TX] AddByte: 0x00 ('.') - queue size now: 6
[PTY TX] AddByte: 0x70 ('p') - queue size now: 7
[PTY ProcessWrite] Writing 7 bytes to fd=99
[PTY ProcessWrite] Data: 70 FF 00 00 00 00 70
[PTY ProcessWrite] Successfully wrote 7 bytes
[PTY RX] GetNextByte: 0x41 ('A') - queue size now: 1
[PTY RX] GetNextByte: 0x43 ('C') - queue size now: 0
```

## Future Commands

The `serial_utils.s` module provides reusable functions for implementing additional FujiNet commands:

- `*FSSID` - Get current SSID
- `*FHOSTS` - List configured hosts
- `*FSLOTS` - Show device slots
- Network commands
- Disk commands

All can use the same utilities:
1. Build packet in `cws_tmp1-7`
2. Call `calc_checksum`
3. Call `setup_serial_19200`
4. Send bytes via OSWRCH
5. Read response via `read_serial_byte`
6. Set USER_FLAG status
7. Call `restore_output_to_screen`

## Success Criteria

✅ Command frame transmitted correctly  
✅ Checksum calculated properly  
✅ Response bytes read and validated  
✅ Status reported via USER_FLAG  
✅ Code refactored for reusability  
✅ Works with b2 emulator + FujiNet firmware  

## Next Steps

1. Implement additional FujiNet commands using serial_utils
2. Add error message printing for debug builds
3. Consider adding verbose mode flag
4. Document serial_utils API for command developers

