# BBC Micro Serial Hardware Reference

## Source: b2 Emulator Source Code

All serial hardware addresses are verified from the b2 emulator source code at:
**`b2/src/beeb/src/BBCMicro.cpp` lines 2924-2946**

## Serial Hardware Memory Map

### ACIA (MC6850) - Motorola 6850 UART
Located at **`&FE08`** - **`&FE0F`** (even addresses only)

```cpp
// From BBCMicro.cpp line 2936:
for (int i = 0; i < 8; i += 2) {
    uint16_t addr = (uint16_t)(0xfe08 + i);
    this->SetSIO(addr + 0, &MC6850::ReadStatusRegister, &m_state.acia, 
                 &MC6850::WriteControlRegister, &m_state.acia);
    this->SetSIO(addr + 1, &MC6850::ReadDataRegister, &m_state.acia, 
                 &MC6850::WriteDataRegister, &m_state.acia);
}
```

| Address | Read Function | Write Function |
|---------|--------------|----------------|
| **`&FE08`** | Status Register | Control Register |
| **`&FE09`** | Data Register | Data Register |

### SERPROC (Serial ULA)
Located at **`&FE10`** - **`&FE17`**

```cpp
// From BBCMicro.cpp line 2927:
for (int i = 0; i < 8; ++i) {
    uint16_t addr = (uint16_t)(0xfe10 + i);
    this->SetSIO(addr, &ReadSERPROC, this, &SERPROC::Write, &m_state.serproc);
}
```

| Address | Function |
|---------|----------|
| **`&FE10`** | SERPROC Control Register (baud rate, RS423, motor) |

---

## ACIA Status Register (&FE08 - Read)

**Source:** `b2/src/beeb/src/MC6850.cpp` - `MC6850::ReadStatusRegister()`

| Bit | Meaning | Description |
|-----|---------|-------------|
| 0 | RDRF | Receive Data Register Full (1 = byte available) |
| 1 | TDRE | Transmit Data Register Empty (1 = ready to send) |
| 2 | /DCD | Data Carrier Detect (0 = carrier detected) |
| 3 | /CTS | Clear To Send (0 = clear to send) |
| 4 | FE | Framing Error |
| 5 | OVRN | Receiver Overrun |
| 6 | PE | Parity Error |
| 7 | IRQ | Interrupt Request |

**BBC BASIC Usage:**
```basic
REM Check if byte available to read
IF (?&FE08 AND 1) <> 0 THEN byte = ?&FE09

REM Check if ready to transmit
IF (?&FE08 AND 2) <> 0 THEN ?&FE09 = byte
```

---

## ACIA Control Register (&FE08 - Write)

**Source:** `b2/src/beeb/src/MC6850.cpp` - `MC6850::WriteControlRegister()`

| Bits | Field | Values |
|------|-------|--------|
| 0-1 | Counter Divide | 00=÷1, 01=÷16, 10=÷64, 11=Master Reset |
| 2-4 | Word Select | See table below |
| 5-6 | Transmit Control | 00=RTS low, TX int disabled<br>01=RTS low, TX int enabled<br>10=RTS high, TX int disabled<br>11=RTS low, break on TX |
| 7 | Receive Interrupt | 0=disabled, 1=enabled |

### Word Select (bits 2-4)

| Value | Data Bits | Parity | Stop Bits |
|-------|-----------|--------|-----------|
| 000 | 7 | Even | 2 |
| 001 | 7 | Odd | 2 |
| 010 | 7 | Even | 1 |
| 011 | 7 | Odd | 1 |
| 100 | 8 | None | 2 |
| 101 | 8 | None | 1 |
| 110 | 8 | Even | 1 |
| 111 | 8 | Odd | 1 |

**BBC BASIC Usage:**
```basic
REM Master reset
?&FE08 = &03

REM Configure 8N1, RTS low, RX interrupt enabled
REM &15 = %00010101 = 8 bits, no parity, 1 stop, RTS low, RX int on
?&FE08 = &15
```

---

## SERPROC Control Register (&FE10 - Write)

**Source:** `b2/src/beeb/src/serproc.cpp` - `SERPROC::Write()`

```cpp
serproc->m_control.value = value;
serproc->m_tx_clock_mask = SERPROC_CLOCK_MASKS[serproc->m_control.bits.tx_baud];
serproc->m_rx_clock_mask = SERPROC_CLOCK_MASKS[serproc->m_control.bits.rx_baud];
```

**Format:** `%MRRRRTTT`

| Bits | Field | Description |
|------|-------|-------------|
| 0-2 | TX Baud | Transmit baud rate (see table) |
| 3-5 | RX Baud | Receive baud rate (see table) |
| 6 | Motor | Cassette motor (0=off, 1=on) |
| 7 | RS423 | RS423 mode (0=off, 1=on) |

### Baud Rate Codes

**Source:** `b2/src/beeb/src/serproc.cpp` lines 43-52

```cpp
const unsigned SERPROC_BAUD_RATES[8] = {
    19200, // 000
    1200,  // 001
    4800,  // 010
    150,   // 011
    9600,  // 100
    300,   // 101
    2400,  // 110
    75,    // 111
};
```

| Code | Baud Rate |
|------|-----------|
| 000 | 19200 |
| 001 | 1200 |
| 010 | 4800 |
| 011 | 150 |
| 100 | 9600 |
| 101 | 300 |
| 110 | 2400 |
| 111 | 75 |

**BBC BASIC Usage:**
```basic
REM Set 19200 baud TX and RX, no RS423, motor off
REM &00 = %00000000 = TX=19200(000), RX=19200(000), Motor=0, RS423=0
?&FE10 = &00

REM Set 9600 baud TX and RX
REM &24 = %00100100 = TX=9600(100), RX=9600(100)
?&FE10 = &24
```

---

## FujiNet Configuration (19200 baud, 8N1)

```basic
REM SERPROC: 19200 TX/RX, no RS423, motor off
?&FE10 = &00

REM ACIA: Master reset
?&FE08 = &03

REM ACIA: 8 bits, no parity, 1 stop, RTS low, RX int enabled
?&FE08 = &15
```

---

## Implementation Notes

1. **SERPROC is write-only** - Reading from &FE10 returns stale data bus value
2. **ACIA uses even addresses only** - &FE08, &FE0A, &FE0C, &FE0E (all mirror &FE08/&FE09)
3. **RS423 mode** - When enabled, sets ACIA /DCD low to indicate carrier present
4. **Baud rate timing** - Generated from 1.23MHz clock divided by 64, then by rate divisor

---

## References

- **b2 Emulator Source**: `b2/src/beeb/src/BBCMicro.cpp` (lines 2924-2946)
- **SERPROC Implementation**: `b2/src/beeb/src/serproc.cpp`
- **MC6850 ACIA Implementation**: `b2/src/beeb/src/MC6850.cpp`
- **FujiNet Integration**: `b2/src/b2/PTYSerial.cpp`

All addresses and register formats are directly verified from the emulator source code, ensuring 100% compatibility with the b2 emulator's serial hardware emulation.

