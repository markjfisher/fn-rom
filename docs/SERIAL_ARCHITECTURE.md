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
│  │ High Level   │  │ Policy /     │  │ Shared FujiBus     │     │
│  │ (MMFS compat)│→ │ Transaction  │→ │ protocol           │     │
│  │ fs_functions │  │ fuji_fs/mount│  │ fujibus*.s         │     │
│  └──────────────┘  └──────────────┘  └────────────────────┘     │
│                                              ↓                  │
│                                       [Shared SLIP]             │
│                                       fuji_link_slip.s          │
│                                              ↓                  │
│                                       [Raw Channel]             │
│                                       serial/*.s today          │
│                                       userport/*.s later        │
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
│  │  │ Shared FujiBus protocol                         │     │      │
│  │  │                                                 │     │      │
│  │  │  • fujibus.s packet encode/decode               │     │      │
│  │  │  • fujibus_disk/fuji/network command builders   │     │      │
│  │  │  • fuji_data_fujibus exported data operations   │     │      │
│  │  └─────────────────────────────────────────────────┘     │      │
│  │                           ↓                              │      │
│  │  ┌─────────────────────────────────────────────────┐     │      │
│  │  │ Shared SLIP framing                             │     │      │
│  │  │                                                 │     │      │
│  │  │  • fuji_link_slip.s                             │     │      │
│  │  │  • fuji_link_*_slip_frame entry points          │     │      │
│  │  └─────────────────────────────────────────────────┘     │      │
│  │                           ↓                              │      │
│  │  ┌─────────────────────────────────────────────────┐     │      │
│  │  │ Serial raw-link implementation                  │     │      │
│  │  │                                                 │     │      │
│  │  │  • serial_utils.s setup/restore/RS423 helpers   │     │      │
│  │  │  • fuji_link_setup / read_byte / write_byte     │     │      │
│  │  │  • Raw byte read/write for current transport    │     │      │
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

## Serial Channel Role

Serial is now only the raw-link implementation underneath the shared FujiBus and SLIP layers. That means:

- `fuji_mount.s` and `fuji_fs.s` do not call `fuji_serial.s` for normal data-path work
- `fuji_data_fujibus.s` exports the shared `fuji_*_data` operations
- `fuji_link_slip.s` implements shared SLIP framing over a raw link
- `src/serial/*.s` provides the raw-link symbols: `fuji_link_setup`, `fuji_link_restore_default_io`, `fuji_link_check_byte_available`, `fuji_link_read_byte`, and `fuji_link_write_byte`

When user port or 1MHz is added with the same SLIP + FujiBus protocol, only the channel implementation should need to change.

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

## Related Documents

- [Architecture Overview](ARCHITECTURE.md)
- Phase test plans (PHASE*.md)
