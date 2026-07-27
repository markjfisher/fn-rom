# FujiNet ROM Architecture

## Overview

The FujiNet ROM implements a BBC Micro Disk Filing System (DFS) compatible interface that communicates with FujiNet hardware over a network connection. The architecture is based on MMFS (Master Micro Filing System) but adapted for network operations instead of MMC/SD card access.

## Product source layout

Orthogonal to the layering below, the source is grouped by residency. The product
ROM always includes disk and network support; bulky utilities are built as
boot/config disk binaries.

| Dir | Linked when | Contains |
|-----|-------------|----------|
| `src/kernel/` | always | filing-system vectors, transport/channel, init, command matcher + tables, bootstrap/recovery commands (`*FHOST`/`*FIN`/`*FMOUNT`/`*FBOOT`), `*CAT`/`*RUN` |
| `src/disk/`   | always | DFS catalog + sector IO + the disk branch of the shared vectors |
| `src/net/`    | always | network FujiBus builders, the network vector branch, `*FJSON`, OSWORD &78 |
| `src/utils/`  | never in ROM | management/informational commands built onto the boot/config utilities disk, `FN-UTLS.ssd` |

The disk and network paths meet only at well-defined dispatch points inside the
shared MOS filing vectors (`OSFIND`/`OSBGET`/`OSBPUT`/close). There is no
ALL/DISK/DISK+NET release matrix now: `make all` builds the product ROM, and
`make all BUILD_MACHINE=MASTER` builds the Master product ROM.

The forward boundary is intentionally strict: ROM space is for the resident
filing system, transport/channel code, device protocols, OSWORD contracts,
bootstrap/recovery commands, and thin wrappers over resident APIs. Utility apps
and bulky management/informational commands live on the boot/config disk so BBC
and Master builds keep headroom for functionality that cannot be supplied from
disk.

## Layer Architecture

The system now separates FujiNet operations into policy, shared FujiBus protocol, and channel-specific I/O. This keeps packet definitions shared across serial, user port, and future 1MHz implementations while only the raw byte stream varies by interface.

```
┌─────────────────────────────────────────────────────────────┐
│  High-Level Layer (MMFS-Compatible)                         │
│  - OSFILE operations (load, save, delete, etc.)             │
│  - OSFIND operations (open, close)                          │
│  - BPUT/BGET (byte read/write)                              │
│  - Command handlers (*CAT, *INFO, *RUN, etc.)               │
│  Files: vectors/filev/*.s, vectors/bputv_entry.s, etc.      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Transaction / Policy Layer                                 │
│  - fuji_read_catalog() / fuji_write_catalog()               │
│  - fuji_mount_disk() / fuji_get_slot()                      │
│  - fuji_begin_transaction() / fuji_end_transaction()        │
│  Files: fuji_fs.s, fuji_mount.s                             │
│  CRITICAL: All functions here manage &BC-&CB preservation   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Shared FujiBus Operations                                  │
│  - fuji_*_data() exports backed by FujiBus                  │
│  - fujibus_disk.s / fujibus_fuji.s / fujibus_network.s      │
│  - Packet layout and response validation                    │
│  Files: fuji_data_fujibus.s, fujibus*.s                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Shared Framing Layer                                       │
│  - fuji_link_read_slip_frame()                              │
│  - fuji_link_write_slip_frame()                             │
│  - fuji_link_write_slip_frame_dual()                        │
│  - SLIP encode/decode over the selected link                │
│  File: fuji_link_slip.s                                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Raw Link / Channel Layer                                   │
│  - fuji_link_setup() / fuji_link_restore_default_io()       │
│  - fuji_link_check_byte_available() / fuji_link_read_byte() │
│  - fuji_link_write_byte()                                   │
│  - Physical serial today, userport/1MHz later               │
│  Files: serial/*.s today, userport/*.s later                │
└─────────────────────────────────────────────────────────────┘
```

### Current File Responsibilities

- `fuji_fs.s` and `fuji_mount.s`: top-level FujiNet operations, state, transaction boundaries
- `fuji_data_fujibus.s`: shared `fuji_*_data` implementations for mount, catalog, and block operations
- `fujibus.s`: shared FujiBus packet encode/decode and checksum handling
- `fujibus_disk.s`, `fujibus_fuji.s`, `fujibus_network.s`: shared device-specific FujiBus commands
- `fuji_link_slip.s`: shared SLIP framing over the selected raw link
- `src/serial/*.s`: current serial raw-link implementation used by the shared SLIP layer
- `fuji_serial.s`: serial-only error helpers, not the main FujiBus data path

## Transaction Management and Zero Page Protection

### The Problem

BBC Micro DFS uses zero page locations `&BC-&CB` to pass parameters and hold critical file operation data:
- `&BC/&BD` - Buffer address (load address)
- `&BE/&BF` - **Exec address** (crucial for *RUN command)
- `&C0/&C1` - File length
- `&C2/&C3` - Start sector / mixed byte

Hardware operations need to use these same zero page locations as scratch space. If not properly managed, this corrupts critical data like the exec address.

### MMFS Solution

MMFS uses `MMC_BEGIN` and `MMC_END` functions:
- `MMC_BEGIN` (called via `DiskStart` → `CalcRWVars`) saves `&BC-&CB` to workspace at `MA+&1090`
- Hardware layer (`MMC_ReadBlock`, `MMC_WriteBlock`) can freely use `&BC-&CB`
- `MMC_END` restores `&BC-&CB` from workspace after hardware operation completes

### FujiNet Solution

We implement the same pattern using `fuji_begin_transaction` and `fuji_end_transaction`:

```assembly
fuji_begin_transaction:
    ; Save &BC-&CB (16 bytes) to workspace at $1090
    ldx     #$0F
@save_loop:
    lda     aws_tmp12,x              ; aws_tmp12 = &BC
    sta     $1090,x
    dex
    bpl     @save_loop
    rts

fuji_end_transaction:
    ; Restore &BC-&CB from workspace
    ldx     #$0F
@restore_loop:
    lda     $1090,x
    sta     aws_tmp12,x
    dex
    bpl     @restore_loop
    rts
```

### Critical Rule: Transaction Management ONLY in fuji_fs.s

**All hardware interface functions in `fuji_fs.s` wrap their operations with transactions:**

```assembly
; Example: fuji_read_mem_block
fuji_read_mem_block:
    jsr     fuji_begin_transaction   ; Save &BC-&CB
    lda     #$85                     ; Read operation
    jsr     fuji_execute_block_rw    ; Hardware operation (can use &BC-&CB)
    jsr     fuji_end_transaction     ; Restore &BC-&CB
    lda     #1                       ; Success
    rts
```

**High-level code does NOT manage transactions:**

```assembly
; In osfileFF_loadfiletoaddr.s
LoadMemBlock:
    jsr     fuji_read_mem_block      ; Transaction already managed!
    rts

; In osfile_functions.s
save_mem_block:
    jsr     fuji_write_mem_block     ; Transaction already managed!
    rts
```

## Transaction-Wrapped Interface Functions

The transaction-wrapped entry points remain in `fuji_fs.s` and `fuji_mount.s`. They call shared `fuji_*_data` implementations underneath.

| Function | Purpose | Transaction? |
|----------|---------|--------------|
| `fuji_read_catalog` | Read disk catalog (512 bytes) | ✅ Yes |
| `fuji_write_catalog` | Write disk catalog | ✅ Yes |
| `fuji_read_mem_block` | Read memory block (OSFILE operations) | ✅ Yes |
| `fuji_write_mem_block` | Write memory block (OSFILE operations) | ✅ Yes |
| `fuji_begin_transaction` | Save &BC-&CB to workspace | N/A |
| `fuji_end_transaction` | Restore &BC-&CB from workspace | N/A |

## Memory Layout and Workspace

### Zero Page Workspace (`&BC-&CB`)

```
&BC (aws_tmp12) - Buffer address low / General temp
&BD (aws_tmp13) - Buffer address high / General temp
&BE (aws_tmp14) - Exec address low / Block size low
&BF (aws_tmp15) - Exec address high / Block size high
&C0 (pws_tmp00) - File length low / Sector count
&C1 (pws_tmp01) - File length high
&C2 (pws_tmp02) - Mixed byte / Start sector high
&C3 (pws_tmp03) - Start sector low
&C4-&CB         - Additional workspace
```

### Saved Workspace (`$1090-$109F`)

During transactions, `&BC-&CB` is saved here to allow hardware operations to use these locations freely.

### Private Workspace (`&CC-&CF`)

```
&CC (pws_tmp12) - Private temp (safe from transaction saves)
&CD (pws_tmp13) - Private temp / CurrentDrv
&CE (pws_tmp14) - Private temp
&CF (pws_tmp15) - Private temp
```

These can be used by the FujiBus or channel implementations if needed, though `&BC-&CB` is preferred since it's protected by transactions.

## Adapter Layer: fuji_execute_block_rw

`fuji_execute_block_rw` is a special adapter that converts MMFS workspace format to FujiNet function calls:

**Input (MMFS format)**:
- `&BC/&BD` - Buffer address
- `&C2/&C3` - Sector number (mixed byte format)
- `&C0/&C1` - Sector count
- `A` register - Operation (`$85`=read, `$A5`=write)

**Output (FujiNet format)**:
- Calls `fuji_read_block_data` or `fuji_write_block_data`
- Sets `fuji_buffer_addr`, `fuji_file_offset`, `fuji_block_size`

This adapter lives in `vectors/filev/fuji_execute_block_rw.s` but is only called from `fuji_fs.s`, maintaining the layer boundary.

## Call Flow Example: *RUN Command

```
1. User types: *RUN HELLO

2. cmd_run.s: fscv2_4_11_starRUN
   ↓ Finds file in catalog, Y = catalog offset

3. osfileFF_loadfiletoaddr.s: LoadFile_Ycatoffset
   ↓ Copies catalog data to &BC-&C3
   ↓ &BE/&BF now contains exec address!
   ↓ Calls LoadMemBlock

4. osfileFF_loadfiletoaddr.s: LoadMemBlock
   ↓ Calls fuji_read_mem_block

5. fuji_fs.s: fuji_read_mem_block
   ↓ Calls fuji_begin_transaction (saves &BC-&CB to $1090)
   ↓ Calls fuji_execute_block_rw
   ↓ Hardware operation happens (may use &BC-&CB as scratch)
   ↓ Calls fuji_end_transaction (restores &BC-&CB from $1090)
   ↓ Returns with &BE/&BF intact!

6. Back to cmd_run.s
   ↓ Jumps to address in &BE/&BF (exec address preserved!)
   ↓ Program runs correctly!
```

## Why This Architecture Matters

- Transaction management centralized in `fuji_fs.s`
- Hardware layer can safely use `&BC-&CB` (protected by transactions)
- **Exec address preserved across hardware operations**
- *RUN command works correctly
- Clean separation of concerns

## Adding New Operations

When adding new FujiNet operations, follow this pattern:

1. **Add a shared `fuji_*_data` function when the protocol is common across interfaces**:
```assembly
fuji_new_operation_data:
    ; Implement FujiBus-backed operation
    ; Can use &BC-&CB freely (will be protected by caller)
    rts
```

2. **Add a transaction-wrapped entry point to `fuji_fs.s` or `fuji_mount.s`**:
```assembly
        .export fuji_new_operation
        .import fuji_new_operation_data

fuji_new_operation:
    jsr     remember_axy
    jsr     fuji_begin_transaction   ; Protect &BC-&CB
    ; Set up parameters
    jsr     fuji_new_operation_data  ; Call hardware
    jsr     fuji_end_transaction     ; Restore &BC-&CB
    rts
```

3. **Only add channel-specific code if the raw byte stream changes**:
```assembly
; serial/*.s or userport/*.s
fuji_link_write_byte:
    ; Write one byte over the selected physical link
    rts
```

## Related Documentation

- `MMFS/mmfs100.asm` lines 2007-2024 - MMFS LoadMemBlock pattern
- `MMFS/MMC.asm` lines 866-879 - MMFS MMC_END implementation

## Key Takeaways

1. **All transaction management happens in `fuji_fs.s`** - never in high-level code
2. **Hardware layer can use `&BC-&CB` freely** - transactions protect it
3. **`&BE/&BF` contains exec address** - critical for *RUN to work
4. **Shared FujiBus and SLIP live above the raw channel layer** - packet and framing code are not duplicated per interface
5. **Only the raw byte-stream channel should vary between serial, user port, and 1MHz**
6. **Matches MMFS transaction discipline while keeping FujiBus reusable**
