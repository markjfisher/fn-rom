# *FRESET Command Implementation

## Overview

The `*FRESET` command sends a hardware reset frame to the FujiNet device via the serial interface.

## Usage

```
*FRESET
```

No parameters required. The command sends a reset packet to the FujiNet device at address 0x70.

## Implementation Details

### Command Registration

- **Table**: `cmd_table_futils` (commands prefixed with "F")
- **Function**: `cmd_fs_freset` in `src/commands/cmd_freset.s`
- **Parameters**: None (`$80+$00`)

### Packet Format

The reset command sends a 7-byte packet:

```
[Device] [Cmd1] [Cmd2] [Cmd3] [Cmd4] [Cmd5] [Checksum]
  0x70    0xFF   0x00   0x00   0x00   0x00   [calc]
```

**Checksum Calculation**: Sum of device byte + 5 command bytes (low byte only)
- For reset: `(0x70 + 0xFF + 0x00 + 0x00 + 0x00 + 0x00) & 0xFF = 0x6F`

### Serial Hardware Configuration

The command initializes the serial hardware on each invocation:

1. **SERPROC (`&FE10`)**: Set to `&00` for 19200 baud TX/RX
2. **ACIA (`&FE08`)**: 
   - Master reset (`&03`)
   - Configure for 8N1, RTS low, RX int enabled (`&15`)

### Workspace Usage

Uses command workspace variables (`cws_tmp1` through `cws_tmp7`):
- `cws_tmp1`: Device byte (0x70)
- `cws_tmp2-6`: Command bytes (FF 00 00 00 00)
- `cws_tmp7`: Calculated checksum

## Code Structure

### Main Function: `cmd_fs_freset`

```assembly
cmd_fs_freset:
    jsr     init_serial         ; Configure serial hardware
    ; Build packet in workspace
    ; Calculate checksum
    ; Send 7 bytes via ACIA
    rts
```

### Helper Functions

1. **`init_serial`**: Configures SERPROC and ACIA for 19200 baud, 8N1
2. **`calc_checksum`**: Sums device + command bytes (6 bytes total)
3. **`send_byte`**: Waits for ACIA ready (TDRE bit) and sends byte

## Hardware Addresses

From b2 emulator source (`BBCMicro.cpp`):

| Address | Register | Access |
|---------|----------|--------|
| `&FE08` | ACIA Control/Status | R/W |
| `&FE09` | ACIA Data | R/W |
| `&FE10` | SERPROC Control | W |

## Testing

### In BBC BASIC

```basic
*FRESET
```

Should send the reset frame to the FujiNet device. You can verify using:
- b2 emulator with FujiNet PTY connection
- `send-packet.py` listening on the PTY endpoint

### Expected Serial Output

7 bytes: `70 FF 00 00 00 00 6F`

## Files Modified

1. **`src/commands/cmd_freset.s`** (new) - Implementation
2. **`src/commands/cmd_tables.s`** - Added command registration:
   - Import: `cmd_fs_freset`
   - Table: Added "RESET" to `cmd_table_futils`
   - Function table: Added `cmd_fs_freset-1` to `cmd_table_futils_cmds`

## Build

```bash
make BUILD_INTERFACE=SERIAL
```

The ROM automatically includes all `.s` files via the Makefile wildcard pattern.

## Related Documentation

- `SERIAL_HARDWARE_REFERENCE.md` - Complete serial hardware documentation
- `B2_SERIAL_INTEGRATION.md` - b2 emulator serial integration
- `bas/FUJITST.bas` - BASIC test program with similar serial code
- `ARCHITECTURE.md` - ROM architecture and workspace usage

## Future Enhancements

This command provides a template for implementing other FujiNet protocol commands:

1. **Status Query** - Read device status
2. **Network Commands** - Network configuration and operations
3. **Disk Operations** - Additional disk commands
4. **Configuration** - Device configuration commands

Each would follow the same pattern:
- Build packet in workspace
- Calculate checksum
- Send via `send_byte` helper
- Optionally read response using ACIA RDRF bit

## Checksum Algorithm

The checksum is a simple sum of all data bytes (device + command), keeping only the low byte:

```assembly
calc_checksum:
    lda     #0              ; Start with 0
    ldx     #0
@loop:
    clc
    adc     workspace,x     ; Add byte
    inx
    cpx     #6              ; All 6 bytes?
    bne     @loop
    rts                     ; A = checksum
```

This matches the Python implementation in `send-packet.py`:

```python
def create_checksum(data):
    checksum = 0
    for byte in data:
        checksum = (checksum + byte) & 0xFF
    return checksum
```

