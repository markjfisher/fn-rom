# B2 FujiNet Integration - Testing Guide

##⚠️ Important Fix Applied

**RX Path Now Implemented!** The original SERPROC code was only sending TX data. I've now implemented the complete RX (receive) path so the emulated BBC can receive data from the PTY device.

---

## Testing Strategy

### 1. Quick Test with Menu Item (TODO)

We can add a menu item in b2 to send a test packet (`70 00 00 00 00` + checksum `70`) to verify the PTY connection works.

### 2. Test with BBC BASIC Programs ✅ WORKS NOW!

**YES!** This is now fully hooked up to the BBC's serial hardware. You can write BBC BASIC programs that use the serial port.

#### BBC Serial Hardware Addresses:
- `&FE08` - ACIA Status/Control Register
- `&FE09` - ACIA Data Register  
- `&FE10` - SERPROC Control Register (baud rate, RS423, motor)

#### Simple BBC BASIC Test Program:

```basic
10 REM Test FujiNet Serial Communication
20 REM
30 REM Configure SERPROC for 19200 baud
40 ?&FE10=&00  :REM TX=19200, RX=19200, RS423=0, Motor=0
50 REM
60 REM Configure ACIA
70 ?&FE08=&03  :REM Master reset
80 ?&FE08=&15  :REM 8N1, RTS low, TX interrupt disabled, RX interrupt enabled
90 REM
100 REM Wait for ACIA ready
110 IF (?&FE08 AND &02)=0 THEN GOTO 110
120 REM
130 REM Send test packet: 70 00 00 00 00 70 (checksum)
140 ?&FE09=&70  :REM Device byte
150 ?&FE09=&00  :REM Command byte 1
160 ?&FE09=&00  :REM Command byte 2
170 ?&FE09=&00  :REM Command byte 3
180 ?&FE09=&00  :REM Command byte 4
190 ?&FE09=&70  :REM Checksum
200 REM
210 PRINT "Packet sent!"
220 REM
230 REM Wait for response
240 timeout%=10000
250 FOR I%=1 TO timeout%
260   IF (?&FE08 AND &01)<>0 THEN GOTO 290
270 NEXT I%
280 PRINT "No response":END
290 REM
300 REM Read response byte
310 byte%=?&FE09
320 PRINT "Received: ";~byte%
330 REM
340 REM Continue reading response
350 FOR I%=1 TO 100
360   IF (?&FE08 AND &01)=0 THEN GOTO 390
370   PRINT " ";~?&FE09;
380 NEXT I%
390 PRINT
400 PRINT "Done"
```

---

## Test Setup

### Step 1: Start the Bridge

```bash
cd /home/markf/dev/bbc/fn-rom/serial-bridge
./create-link.sh
```

This creates:
- `/tmp/fn-tty` - PTY for b2 emulator to connect to
- `/tmp/inject-tty` - PTY for send-packet.py to inject test responses

### Step 2: Configure b2 Emulator

1. Launch b2 emulator
2. Go to **Settings → Configs**
3. Enable **FujiNet** checkbox
4. Configure:
   - **Interface**: Serial
   - **Device Mode**: PTY/Virtual
   - **Device Path**: `/tmp/fn-tty`
   - **Auto-connect**: ☑
   - **Debug logging**: ☑
5. Click **OK** to save

###Step 3: Load Configuration

Either:
- Restart the emulator, OR
- Reload the config (Settings → Load Default Config)

You should see in the **Messages** window:
```
FujiNet: Connected to /tmp/fn-tty
FujiNet: Connected to SERPROC
```

If debug is enabled, you'll also see TX/RX messages.

### Step 4: Test from BBC BASIC

1. **Enter the BBC BASIC program above** (or load it from disc)
2. **Run it** with `RUN`
3. **Watch the Messages window** - you should see:
   ```
   PTYSerial: TX 6 bytes
   ```
   
4. **In another terminal, send a response:**
   ```bash
   cd /home/markf/dev/bbc/fn-rom/serial-bridge
   # Send ACK + COMPLETE + "Hello" + checksum
   echo -ne '\x41\x43\x48\x65\x6c\x6c\x6f\x1c' > /tmp/inject-tty
   ```

5. **Back in BBC BASIC**, you should see:
   ```
   Packet sent!
   Received: 41
    43 48 65 6C 6C 6F 1C
   Done
   ```

---

## Test with send-packet.py

You can also use the Python script to send FujiNet protocol packets:

```bash
cd /home/markf/dev/bbc/fn-rom/serial-bridge

# Send a test packet and read response
./send-packet.py -e /tmp/inject-tty -c test -r

# Send custom packet
./send-packet.py -e /tmp/inject-tty -d 70 FF 00 00 00 00 -r
```

---

## Understanding Serial Flow

```
┌─────────────────────────────────────────────────────┐
│              BBC BASIC Program                       │
│              ?&FE08, ?&FE09                         │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────┐
        │   MC6850 ACIA    │  (Emulated)
        │   (Serial chip)  │
        └────────┬──────────┘
                 │
                 ▼
        ┌──────────────────┐
        │    SERPROC       │  (Emulated)
        │  (Baud/Control)  │
        └────────┬──────────┘
                 │
                 ▼
        ┌──────────────────┐
        │  PTYSerialDevice │  (b2 code)
        │  TX/RX Buffers   │
        └────────┬──────────┘
                 │
                 ▼
        ┌──────────────────┐
        │   /tmp/fn-tty    │  (PTY device)
        └────────┬──────────┘
                 │
                 ▼
        ┌──────────────────┐
        │ Bridge / FujiNet │
        │     Hardware     │
        └──────────────────┘
```

---

## SERPROC Baud Rate Codes

The SERPROC control register (`&FE10`) format:
```
Bits 0-2: TX baud rate
Bits 3-5: RX baud rate  
Bit 6: RS423 mode (0=off, 1=on)
Bit 7: Motor (0=off, 1=on)
```

Baud rate values:
```
000 = 19200 (FujiNet default)
001 = 1200
010 = 4800
011 = 150
100 = 9600
101 = 300
110 = 2400
111 = 75
```

For FujiNet (19200 baud, no RS423, no motor):
```basic
?&FE10 = &00
```

---

## Known Limitations

1. **0x00 bytes**: Currently, the RX path treats `0x00` as "no data" which means you can't reliably receive null bytes. This will be fixed by adding a proper `HasData()` method to `SerialDataSource`.

2. **User Port mode**: Not yet implemented (only Serial ACIA works).

3. **Flow control**: None implemented (raw mode only).

---

## Troubleshooting

### "No connection" or "Failed to open"
- Check that `/tmp/fn-tty` exists (run `create-link.sh`)
- Check permissions on the PTY device
- Check that another process isn't using it

### "No data received"
- Make sure debug logging is enabled to see TX/RX activity
- Check that the bridge is running
- Verify the PTY path is correct in both b2 config and your test script

### "Garbled data"
- Check baud rate matches (19200)
- Verify ACIA is configured correctly (&15 for 8N1)
- Check that SERPROC is set to 19200 (&00)

---

## Advanced: Monitoring Serial Traffic

Use `screen` to monitor the PTY:
```bash
# In one terminal:
screen /tmp/fn-tty 19200

# In another terminal:
# Run your b2 emulator and BBC BASIC program
```

You'll see raw serial data flowing through the PTY.

Or use `hexdump`:
```bash
hexdump -C < /tmp/fn-tty
```

---

## Next Steps

1. Test with real FujiNet ROM commands
2. Test FujiNet network operations
3. Add connection status indicator in UI
4. Improve RX to handle 0x00 bytes properly
5. Add menu item for quick test packet

---

**Ready to Test!** 🚀

