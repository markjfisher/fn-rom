# FujiNet BBC BASIC Test Programs

These programs test serial communication with FujiNet devices via the b2 emulator.

## Programs

### FUJITST.bas
Simple test that:
- Configures the ACIA and SERPROC for 19200 baud
- Sends a test packet: `70 00 00 00 00 70`
- Waits for and displays the response

**Usage:**
1. Load: `*LOAD FUJITST`
2. Run: `RUN`
3. In another terminal, inject a test response:
   ```bash
   echo -ne '\x41\x43Hello\x1c' > /tmp/inject-tty
   ```

### FUJIECHO.bas
Interactive program that:
- Prompts for commands
- Sends each command as a FujiNet packet (device 0x70)
- Displays responses in hex and ASCII
- Loops until you type "QUIT"

**Usage:**
1. Load: `*LOAD FUJIECHO`
2. Run: `RUN`
3. Enter commands at the prompt

## Serial Hardware Addresses

| Address | Register | Purpose |
|---------|----------|---------|
| `&FE08` | ACIA Control/Status | Configure ACIA, check TX/RX status |
| `&FE09` | ACIA Data | Send/receive bytes |
| `&FE10` | SERPROC Control | Set baud rate, RS423 mode, motor |

## ACIA Status Register (&FE08)

Reading `?&FE08` returns status:
- Bit 0: RX data available (1 = byte ready to read)
- Bit 1: TX ready (1 = can send byte)
- Bit 2: DCD (Data Carrier Detect)
- Bit 3: CTS (Clear To Send)
- Bit 4: Framing error
- Bit 5: RX overrun
- Bit 6: Parity error
- Bit 7: IRQ flag

## ACIA Control Register (&FE08)

Writing to `?&FE08` configures ACIA:
- `&03` = Master reset
- `&15` = 8N1, RTS low, TX interrupt disabled, RX interrupt enabled

## SERPROC Control Register (&FE10)

Format: `%MRRRRTTT`
- Bits 0-2 (TTT): TX baud rate
- Bits 3-5 (RRR): RX baud rate
- Bit 6 (M): Motor (cassette)
- Bit 7 (R): RS423 mode

Baud rate codes:
- `000` = 19200 (FujiNet default)
- `001` = 1200
- `010` = 4800
- `011` = 150
- `100` = 9600
- `101` = 300
- `110` = 2400
- `111` = 75

For FujiNet (19200/19200): `?&FE10 = &00`

## FujiNet Packet Format

```
┌────────┬──────────────────┬──────────┐
│ Device │   Data (5 bytes) │ Checksum │
├────────┼──────────────────┼──────────┤
│  0x70  │  00 00 00 00 00  │   0x70   │
└────────┴──────────────────┴──────────┘
```

Checksum = Sum of all bytes (device + data) AND 0xFF

## Testing with b2 Emulator

1. **Configure b2:**
   - Settings → Configs
   - Enable "FujiNet"
   - Device Path: `/tmp/fn-tty`
   - Auto-connect: ☑
   - Debug: ☑

2. **Start bridge:**
   ```bash
   cd fn-rom/serial-bridge
   ./create-link.sh
   ```

3. **Load BASIC program in b2:**
   ```
   SHIFT+F12 (insert disc)
   *CAT
   *LOAD FUJITST
   RUN
   ```

4. **Inject test response:**
   ```bash
   # Send: ACK (41) + COMPLETE (43) + "Hello" + checksum
   echo -ne '\x41\x43\x48\x65\x6c\x6c\x6f\x1c' > /tmp/inject-tty
   ```

## Building an SSD

Use the b2 emulator or BeebEm to create an SSD:
1. Create blank SSD
2. `*SAVE FUJITST` with tokenized BASIC
3. `*SAVE FUJIECHO` with tokenized BASIC

Or use `beebasm` or similar tools to build an SSD from these text files.

## Troubleshooting

**No response:**
- Check debug output in b2 Messages window
- Verify `/tmp/fn-tty` exists and is connected
- Check SERPROC and ACIA are configured correctly

**Garbled data:**
- Verify baud rate is 19200 (`?&FE10 = &00`)
- Check ACIA configuration (`?&FE08 = &15`)

**Timeout:**
- Increase timeout value in BASIC program
- Check that bridge/device is actually sending data

## Known Issues

- **0x00 bytes:** Currently cannot reliably receive null bytes due to API limitation. Most FujiNet commands work fine, but binary data with nulls may have gaps.

## See Also

- `fn-rom/docs/B2_TESTING_GUIDE.md` - Complete testing guide
- `fn-rom/docs/B2_FUJINET_INTEGRATION_COMPLETE.md` - Implementation details
- `fn-rom/docs/SERIAL_ARCHITECTURE.md` - FujiNet serial protocol
