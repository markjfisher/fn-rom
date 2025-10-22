# FujiNet Serial Communication Architecture

## Overview

This document outlines the architecture for implementing serial communication between the BBC Micro (running FujiNet ROM) and a FujiNet device (either physical ESP32 hardware or fujinet-software virtual device).

## Deployment Scenarios

The architecture must support multiple deployment configurations:

1. **b2 Emulator → FujiNet Software** (primary development target)
2. **b2 Emulator → Physical FujiNet Device**
3. **Physical BBC → FujiNet Software**
4. **Physical BBC → Physical FujiNet Device**

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FujiNet ROM (fn-rom)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐     │
│  │ High Level   │  │ Mid Level    │  │ Low Level          │     │
│  │ (MMFS compat)│→ │ (fuji_fs.s)  │→ │ (fuji_serial.s or  │     │
│  │ fs_functions │  │              │  │  fuji_dummy.s)     │     │
│  └──────────────┘  └──────────────┘  └────────────────────┘     │
│                                              ↓                  │
│                                       [Serial Protocol]         │
└─────────────────────────────────────────────────────────────────┘
                                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Transport Layer                              │
│                                                                 │
│  BBC Hardware Serial ←─→ RS-423/RS-232 Physical Connection      │
│         OR                                                      │
│  b2 Emulator Serial  ←─→ PTY/TTY/Network Bridge                 │
└─────────────────────────────────────────────────────────────────┘
                                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    FujiNet Device                               │
│                                                                 │
│  Physical ESP32 Firmware  ←─→ RS-232/RS-423 Physical Port       │
│         OR                                                      │
│  fujinet-software Virtual ←─→ PTY/TTY/Network Endpoint          │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Component Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                         BBC / b2 Emulator                          │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ FujiNet ROM                                              │      │
│  │                                                          │      │
│  │  ┌─────────────────────────────────────────────────┐     │      │
│  │  │ fuji_serial.s - Serial Communication Layer      │     │      │
│  │  │                                                 │     │      │
│  │  │  • Write to 6850 ACIA registers (0xFE08-0xFE09) │     │      │
│  │  │  • Read from 6850 ACIA registers                │     │      │
│  │  │  • Implement command/response protocol          │     │      │
│  │  │  • Handle timeouts and retries                  │     │      │
│  │  └─────────────────────────────────────────────────┘     │      │
│  └──────────────────────────────────────────────────────────┘      │
│                              ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ 6850 ACIA (Hardware or Emulated)                         │      │
│  │  • Control Register (0xFE08)                             │      │
│  │  • Status Register (0xFE08)                              │      │
│  │  • Transmit Data Register (0xFE09)                       │      │
│  │  • Receive Data Register (0xFE09)                        │      │
│  └──────────────────────────────────────────────────────────┘      │
│                              ↓                                     │
└────────────────────────────────────────────────────────────────────┘
                               ↓
         ┌─────────────────────┴─────────────────────┐
         ↓                                           ↓
┌─────────────────────┐                    ┌──────────────────────┐
│  Physical RS-423    │                    │  b2 Serial Bridge    │
│  (BBC Hardware)     │                    │  Extension           │
│                     │                    │                      │
│  • TX/RX pins       │                    │  • Intercept ACIA    │
│  • Hardware flow    │                    │    writes/reads      │
│  • 19200 baud       │                    │  • Create PTY/socket │
│  • 8N1              │                    │  • Forward bytes     │
└─────────────────────┘                    │  • Handle flow ctrl  │
         ↓                                 └──────────────────────┘
         ↓                                           ↓
         ↓                                           ↓
    ┌────┴────┐                            ┌─────────┴────────┐
    │ USB/TTY │                            │ PTY/TCP Socket   │
    └────┬────┘                            └─────────┬────────┘
         ↓                                           ↓
         └─────────────────────┬─────────────────────┘
                               ↓
┌────────────────────────────────────────────────────────────────────┐
│                    FujiNet Device / Software                       │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Serial Protocol Handler                                  │      │
│  │  • Parse commands (READ_SECTOR, WRITE_SECTOR, etc.)      │      │
│  │  • Access disk images                                    │      │
│  │  • Send responses                                        │      │
│  │  • Handle errors                                         │      │
│  └──────────────────────────────────────────────────────────┘      │
│                              ↓                                     │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Disk Image Storage                                       │      │
│  │  • SSD/DSD files                                         │      │
│  │  • MMB files (future)                                    │      │
│  │  • Network storage (future)                              │      │
│  └──────────────────────────────────────────────────────────┘      │
└────────────────────────────────────────────────────────────────────┘
```

## Serial Protocol Design

### Protocol Format

```
┌────────────────────────────────────────────────────────┐
│            FujiNet Serial Protocol v1.0                │
│                                                        │
│  Command Format:                                       │
│  ┌────────┬────────┬──────────┬────────┬──────────┐    │
│  │ MAGIC  │  CMD   │  LENGTH  │  DATA  │ CHECKSUM │    │
│  │ 2 bytes│ 1 byte │  2 bytes │ N bytes│  1 byte  │    │
│  └────────┴────────┴──────────┴────────┴──────────┘    │
│                                                        │
│  MAGIC = 0xFD 0xFC                                     │
│                                                        │
│  Commands:                                             │
│  • 0x01: INIT         - Initialize connection          │
│  • 0x10: READ_SECTOR  - Read 256-byte sector           │
│  • 0x11: WRITE_SECTOR - Write 256-byte sector          │
│  • 0x20: READ_CAT     - Read 512-byte catalog          │
│  • 0x21: WRITE_CAT    - Write 512-byte catalog         │
│  • 0x30: GET_STATUS   - Get device status              │
│  • 0xFF: RESET        - Reset connection               │
│                                                        │
│  Response Format:                                      │
│  ┌────────┬────────┬──────────┬────────┬──────────┐    │
│  │ MAGIC  │ STATUS │  LENGTH  │  DATA  │ CHECKSUM │    │
│  │ 2 bytes│ 1 byte │  2 bytes │ N bytes│  1 byte  │    │
│  └────────┴────────┴──────────┴────────┴──────────┘    │
│                                                        │
│  STATUS:                                               │
│  • 0x00: OK                                            │
│  • 0x01: ERROR_CRC                                     │
│  • 0x02: ERROR_TIMEOUT                                 │
│  • 0x03: ERROR_INVALID_CMD                             │
│  • 0x04: ERROR_DISK_ERROR                              │
└────────────────────────────────────────────────────────┘
```

### Command Details

#### READ_SECTOR (0x10)
```
Request:
  MAGIC: 0xFD 0xFC
  CMD: 0x10
  LENGTH: 0x04 0x00 (4 bytes)
  DATA: [DRIVE] [SECTOR_LO] [SECTOR_MID] [SECTOR_HI]
  CHECKSUM: XOR of all bytes

Response:
  MAGIC: 0xFD 0xFC
  STATUS: 0x00 (OK)
  LENGTH: 0x00 0x01 (256 bytes)
  DATA: [256 bytes of sector data]
  CHECKSUM: XOR of all bytes
```

#### WRITE_SECTOR (0x11)
```
Request:
  MAGIC: 0xFD 0xFC
  CMD: 0x11
  LENGTH: 0x04 0x01 (260 bytes)
  DATA: [DRIVE] [SECTOR_LO] [SECTOR_MID] [SECTOR_HI] [256 bytes of sector data]
  CHECKSUM: XOR of all bytes

Response:
  MAGIC: 0xFD 0xFC
  STATUS: 0x00 (OK)
  LENGTH: 0x00 0x00 (0 bytes)
  DATA: none
  CHECKSUM: XOR of all bytes
```

#### READ_CAT (0x20)
```
Request:
  MAGIC: 0xFD 0xFC
  CMD: 0x20
  LENGTH: 0x01 0x00 (1 byte)
  DATA: [DRIVE]
  CHECKSUM: XOR of all bytes

Response:
  MAGIC: 0xFD 0xFC
  STATUS: 0x00 (OK)
  LENGTH: 0x00 0x02 (512 bytes)
  DATA: [512 bytes of catalog data]
  CHECKSUM: XOR of all bytes
```

## UML Sequence Diagram: Read Sector Operation

```
┌─────────┐          ┌────────────┐       ┌──────────┐      ┌──────────┐
│ BBC ROM │          │ fuji_serial│       │ b2 Serial│      │ FujiNet  │
│         │          │    .s      │       │  Bridge  │      │  Device  │
└────┬────┘          └─────┬──────┘       └────┬─────┘      └────┬─────┘
     │                     │                    │                 │
     │ fuji_read_block_data()                   │                 │
     ├──────────────────→  │                    │                 │
     │                     │                    │                 │
     │                     │ Write 0xFD to ACIA │                 │
     │                     ├───────────────────→│                 │
     │                     │                    │ Forward 0xFD    │
     │                     │                    ├────────────────→│
     │                     │ Write 0xFC to ACIA │                 │
     │                     ├───────────────────→│ Forward 0xFC    │
     │                     │                    ├────────────────→│
     │                     │ Write CMD (0x10)   │                 │
     │                     ├───────────────────→│ Forward 0x10    │
     │                     │                    ├────────────────→│
     │                     │ Write LENGTH (0x04)│                 │
     │                     ├───────────────────→│ Forward length  │
     │                     │                    ├────────────────→│
     │                     │ Write DRIVE (0x00) │                 │
     │                     ├───────────────────→│ Forward params  │
     │                     │                    ├────────────────→│
     │                     │ Write SECTOR (0x02)│                 │
     │                     ├───────────────────→│                 │
     │                     │                    │                 │
     │                     │ Write CHECKSUM     │                 │
     │                     ├───────────────────→│                 │
     │                     │                    │                 │
     │                     │                    │                 │ Parse command
     │                     │                    │                 ├─────┐
     │                     │                    │                 │     │
     │                     │                    │                 │←────┘
     │                     │                    │                 │
     │                     │                    │                 │ Read from disk
     │                     │                    │                 ├─────┐
     │                     │                    │                 │     │
     │                     │                    │                 │←────┘
     │                     │                    │   Send 0xFD     │
     │                     │  Read from ACIA    │←────────────────┤
     │                     │←───────────────────┤   Send 0xFC     │
     │                     │  Read from ACIA    │←────────────────┤
     │                     │←───────────────────┤   Send STATUS   │
     │                     │  Read from ACIA    │←────────────────┤
     │                     │←───────────────────┤   Send LENGTH   │
     │                     │  Read from ACIA    │←────────────────┤
     │                     │←───────────────────┤                 │
     │                     │                    │   Send 256 bytes│
     │                     │  Read loop (256x)  │←────────────────┤
     │                     │←───────────────────┤                 │
     │                     │                    │   Send CHECKSUM │
     │                     │  Read from ACIA    │←────────────────┤
     │                     │←───────────────────┤                 │
     │                     │                    │                 │
     │                     │ Verify checksum    │                 │
     │                     ├────┐               │                 │
     │                     │    │               │                 │
     │                     │←───┘               │                 │
     │                     │                    │                 │
     │   Return success    │                    │                 │
     │←────────────────────┤                    │                 │
     │                     │                    │                 │
```

## BBC 6850 ACIA Register Map

The BBC Micro uses a Motorola 6850 ACIA (Asynchronous Communications Interface Adapter) for serial communication:

### Register Addresses
- **0xFE08**: Control/Status Register (read for status, write for control)
- **0xFE09**: Transmit/Receive Data Register

### Control Register (Write to 0xFE08)
```
Bit 7-5: Receive Interrupt Enable (RIE)
Bit 4-2: Transmit Control
Bit 1-0: Counter Divide Select
```

### Status Register (Read from 0xFE08)
```
Bit 7: IRQ (Interrupt Request)
Bit 6: PE (Parity Error)
Bit 5: OVRN (Overrun)
Bit 4: FE (Framing Error)
Bit 3: CTS (Clear To Send)
Bit 2: DCD (Data Carrier Detect)
Bit 1: TDRE (Transmit Data Register Empty)
Bit 0: RDRF (Receive Data Register Full)
```

### Typical Initialization Sequence
```assembly
; Reset ACIA
lda #$03
sta $FE08

; Configure: 8N1, /16 clock, no interrupts
lda #$15
sta $FE08
```

## Implementation Plan

### Phase 1: Serial Protocol Definition
- [ ] Define protocol constants in `src/inc/fujinet.inc`
- [ ] Document command/response formats
- [ ] Define error codes and handling
- [ ] Define timeouts and retry logic
- [ ] Create protocol test suite specification

### Phase 2: fuji_serial.s Implementation
- [ ] Implement ACIA initialization routine
- [ ] Implement low-level byte send primitive
- [ ] Implement low-level byte receive primitive with timeout
- [ ] Implement command framing (magic, length, checksum)
- [ ] Implement response parsing
- [ ] Implement timeout handling (using system timer)
- [ ] Implement retry logic
- [ ] Implement `fuji_read_block_data` using serial protocol
- [ ] Implement `fuji_write_block_data` using serial protocol
- [ ] Implement `fuji_read_catalog_data` using serial protocol
- [ ] Implement `fuji_write_catalog_data` using serial protocol
- [ ] Add debug markers for tracing

### Phase 3: b2 Emulator Extension
- [ ] Study `MMFS.cpp` implementation pattern
- [ ] Create `FujiNetSerial.cpp` and `FujiNetSerial.h`
- [ ] Implement ACIA register intercept (0xFE08/0xFE09)
- [ ] Create PTY/socket for external connection
- [ ] Implement byte forwarding (BBC → PTY)
- [ ] Implement byte receiving (PTY → BBC)
- [ ] Implement ACIA status register emulation
- [ ] Implement flow control (RTS/CTS simulation)
- [ ] Add debug logging (similar to MMFS)
- [ ] Add configuration options (PTY path, baud rate, etc.)
- [ ] Integrate with b2 UI

### Phase 4: FujiNet Software Protocol Handler
- [ ] Implement serial protocol parser
- [ ] Implement command dispatcher
- [ ] Implement READ_SECTOR handler
- [ ] Implement WRITE_SECTOR handler
- [ ] Implement READ_CAT handler
- [ ] Implement WRITE_CAT handler
- [ ] Implement disk image access (SSD/DSD)
- [ ] Implement response generation
- [ ] Add error handling
- [ ] Add logging/debugging
- [ ] Create test disk images

### Phase 5: Testing & Integration
- [ ] Unit tests for protocol encoding/decoding
- [ ] Test: ROM initialization sequence
- [ ] Test: Single sector read
- [ ] Test: Single sector write
- [ ] Test: Catalog read
- [ ] Test: Catalog write
- [ ] Test: Multi-sector operations
- [ ] Integration test: b2 → fujinet-software
- [ ] Performance testing (throughput, latency)
- [ ] Error injection testing
- [ ] Timeout testing
- [ ] Create test BASIC programs
- [ ] Documentation and examples

## Open Questions

### 1. Baud Rate
**Question**: What baud rate should we target?

**Options**:
- 75-19200 baud (BBC hardware range)
- Recommend 19200 for development (fastest)
- Should be configurable

**Decision**: TBD

### 2. Flow Control
**Question**: Should we implement flow control?

**Options**:
- None (simplest, may lose data)
- Hardware flow control (RTS/CTS)
- Software flow control (XON/XOFF)

**Decision**: TBD

### 3. FujiNet Software Protocol
**Question**: Does fujinet-software already have a serial protocol handler?

**Status**: Needs investigation

**Action**: Review fujinet-software repository

### 4. b2 Emulator Architecture
**Question**: Confirm b2's extension architecture?

**Status**: Need to study existing code

**Action**: Review `MMFS.cpp` and other hardware emulation modules

### 5. Checksum Algorithm
**Question**: Which checksum algorithm to use?

**Options**:
- Simple XOR checksum (fast, minimal ROM space)
- CRC-8 (more robust)
- CRC-16 (most robust, more overhead)

**Recommendation**: Start with XOR, upgrade if needed

**Decision**: TBD

### 6. Buffer Sizes
**Question**: Should we implement software buffering in the ROM?

**Considerations**:
- ACIA has small hardware buffers (1-2 bytes)
- Software buffering would smooth out interrupts
- ROM space is limited (16KB)

**Decision**: TBD

### 7. Error Recovery
**Question**: How aggressive should retry logic be?

**Options**:
- Simple: 3 retries then fail
- Aggressive: Automatic reconnection
- User prompt: Ask user to retry

**Decision**: TBD

### 8. Multiple Drives
**Question**: How should the protocol handle drive selection?

**Options**:
- Include drive number in each command (recommended)
- Send separate "SELECT DRIVE" command
- Handle at higher level (transparent to protocol)

**Recommendation**: Include drive number in each command

**Decision**: TBD

### 9. Catalog Caching
**Question**: Should we cache the catalog in RAM to reduce serial traffic?

**Considerations**:
- Pro: Faster access, less serial traffic
- Con: Uses RAM, may be stale
- MMFS caches at 0x0E00-0x0FFF (512 bytes)

**Decision**: TBD

### 10. Interrupt vs Polling
**Question**: Should serial I/O use interrupts or polling?

**Options**:
- Polling: Simpler, ROM waits for data
- Interrupts: More complex, better performance
- Hybrid: Interrupts for receive, polling for transmit

**Recommendation**: Start with polling for simplicity

**Decision**: TBD

## Related Documents

- [Architecture Overview](ARCHITECTURE.md)
- [MMFS Implementation Notes](fuji_dummy_analysis.md)
- Phase test plans (PHASE*.md)

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | AI + User | Initial architecture document |

