; FujiBus Disk Commands for BBC Micro
; Implements disk device commands using FujiBus protocol
;
; Wire Device ID: 0xFC (FN_DEVICE_DISK)
;
; Commands:
;   0x01 - Mount
;   0x02 - Unmount
;   0x03 - ReadSector
;   0x04 - WriteSector
;   0x05 - Info
;   0x06 - ClearChanged
;   0x07 - Create

        ; .export fn_disk_mount
        ; .export fn_disk_unmount
        ; .export fn_disk_read_sector
        ; .export fn_disk_write_sector
        ; .export fn_disk_info

        ; ; Low-level functions called by fuji_serial.s
        ; .export fn_disk_read_sector_impl
        ; .export fn_disk_write_sector_impl

        ; .import fn_build_packet
        ; .import fn_send_packet
        ; .import fn_receive_packet
        ; .import fuji_tx_buffer
        ; .import fuji_rx_buffer
        ; .import fn_tx_len
        ; .import fn_tx_len_hi
        ; .import fn_rx_len
        ; .import _calc_checksum

        ; .import remember_axy
        ; .import fuji_begin_transaction
        ; .import fuji_end_transaction

        .include "fujinet.inc"

;; THIS IS ALL JUNK AND UNTESTED AI CODE

; ============================================================================
; Workspace - use absolute addresses (fuji_workspace = 0)
; ============================================================================

; Current slot (1-based, D1=1) - use a byte in fuji_workspace area
fn_disk_slot    = $10F9
fn_disk_flags   = $10F8

; ============================================================================
; CODE
; ============================================================================

        .segment "CODE"

; ============================================================================
; FN_DISK_MOUNT - Mount a disk image
;
; Request:
;   u8  version = 1
;   u8  slot    = drive number (1-based)
;   u8  flags   = bit0 = readonly_requested
;   u8  typeOverride = 0 (auto-detect)
;   u16 sectorSizeHint = 0
;   u16 fsLen + fsName
;   u16 pathLen + path
;
; Input:
;   A = slot (1-8)
;   X = flags (0=read-write, 1=read-only)
;   aws_tmp00/01 = pointer to full URI string (NUL-terminated)
;   aws_tmp02 = URI length in bytes
;
; Output:
;   Carry clear on success, set on error
; ============================================================================
; fn_disk_mount:
;         ; Build packet payload directly - no stack needed
;         ; Payload starts at offset 6 (after header)
;         ; Payload: version(1) + slot(1) + flags(1) + typeOverride(1) + sectorSizeHint(2)
;         ; Input: A = slot, X = flags

;         ; Save input parameters
;         sta     fn_disk_slot     ; Save slot for later
;         stx     fn_disk_flags    ; Save flags for later

;         ; Version
;         lda     #FN_PROTOCOL_VERSION
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+0

;         ; Slot (from saved value)
;         lda     fn_disk_slot
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+1

;         ; Flags (from saved value)
;         lda     fn_disk_flags
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+2

;         ; Type override = 0 (auto)
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+3

;         ; Sector size hint = 0 (little-endian)
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+4
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+5

;         ; URI length (little-endian)
;         lda     aws_tmp02
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+6
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+7

;         ; Copy URI bytes after length
;         ldy     #$00
; @copy_uri:
;         cpy     aws_tmp02
;         beq     @build_packet
;         lda     (aws_tmp00),y
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+8,y
;         iny
;         bne     @copy_uri

; @build_packet:
;         ; Total payload = fixed fields (8) + URI bytes
;         tya
;         clc
;         adc     #$08
;         tay

;         ; Build packet
;         ; A = device ID, X = command, Y = payload length
;         lda     #FN_DEVICE_DISK
;         ldx     #DISK_CMD_MOUNT

;         jsr     fn_build_packet

;         ; Send packet
;         jsr     fn_send_packet
;         bcs     @mount_error

;         ; Receive response
;         jsr     fn_receive_packet
;         bcs     @mount_error

;         ; Check response - look for mounted flag
;         ldy     #FN_HEADER_SIZE+1
;         lda     fuji_rx_buffer,y
;         and     #$01            ; bit0 = mounted
;         beq     @mount_error

;         ; Success
;         clc
;         rts

; @mount_error:
;         sec
;         rts


; ; ============================================================================
; ; FN_DISK_UNMOUNT - Unmount a disk image
; ;
; ; Request:
; ;   u8  version = 1
; ;   u8  slot
; ;
; ; Input:
; ;   A = slot (1-8)
; ;
; ; Output:
; ;   Carry clear on success, set on error
; ; ============================================================================
; fn_disk_unmount:
;         pha                     ; Save slot

;         ; Build packet payload
;         lda     #FN_PROTOCOL_VERSION
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+0

;         pla                     ; Get slot
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+1

;         ; Build packet
;         lda     #FN_DEVICE_DISK
;         ldx     #DISK_CMD_UNMOUNT
;         ldy     #$02            ; Payload length

;         jsr     fn_build_packet

;         ; Send packet
;         jsr     fn_send_packet
;         bcs     @unmount_error

;         ; Receive response
;         jsr     fn_receive_packet
;         bcs     @unmount_error

;         clc
;         rts

; @unmount_error:
;         sec
;         rts


; ; ============================================================================
; ; FN_DISK_READ_SECTOR - Read a sector from disk
; ;
; ; Request:
; ;   u8  version = 1
; ;   u8  slot
; ;   u32 lba (little-endian)
; ;   u16 maxBytes (little-endian)
; ;
; ; Input:
; ;   A = slot (1-8)
; ;   X/Y = LBA (16-bit sector number, for larger use direct ZP)
; ;   aws_tmp08/09 = buffer pointer for data
; ;
; ; Output:
; ;   Data in buffer
; ;   Carry clear on success, set on error
; ; ============================================================================
; fn_disk_read_sector:
;         ; Save parameters
;         sta     fn_disk_slot
;         stx     aws_tmp00       ; LBA low
;         sty     aws_tmp01       ; LBA high

;         ; Build packet payload
;         ; version(1) + slot(1) + lba(4) + maxBytes(2) = 8 bytes

;         ; Version
;         lda     #FN_PROTOCOL_VERSION
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+0

;         ; Slot
;         lda     fn_disk_slot
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+1

;         ; LBA (32-bit, little-endian) - we only support 16-bit for now
;         lda     aws_tmp00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+2
;         lda     aws_tmp01
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+3
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+4
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+5

;         ; Max bytes = 256 (little-endian)
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+6
;         lda     #$01
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+7

;         ; Build packet
;         lda     #FN_DEVICE_DISK
;         ldx     #DISK_CMD_READ_SECTOR
;         ldy     #$08            ; Payload length

;         jsr     fn_build_packet

;         ; Send packet
;         jsr     fn_send_packet
;         bcs     @read_error

;         ; Receive response
;         jsr     fn_receive_packet
;         bcs     @read_error

;         ; Copy data to destination buffer
;         ; Response format: version(1) + flags(1) + reserved(2) + slot(1) + lbaEcho(4) + dataLen(2) + data
;         ; Data starts at offset: 6 + 1 + 1 + 2 + 1 + 4 + 2 = 17

;         ; Get data length from response
;         ldy     #FN_HEADER_SIZE+11
;         lda     fuji_rx_buffer,y  ; dataLen low
;         sta     aws_tmp02
;         iny
;         lda     fuji_rx_buffer,y  ; dataLen high
;         sta     aws_tmp03

;         ; Copy data
;         ; Source: fuji_rx_buffer + 17
;         ; Dest: aws_tmp08/09
;         ldy     #$00
; @copy_loop:
;         lda     fuji_rx_buffer+FN_HEADER_SIZE+13,y
;         sta     (aws_tmp08),y
;         iny
;         cpy     aws_tmp02
;         bne     @copy_loop

;         clc
;         rts

; @read_error:
;         sec
;         rts


; ; ============================================================================
; ; FN_DISK_READ_SECTOR_IMPL - Low-level read for fuji_serial.s
; ;
; ; This is the implementation function called by fuji_read_block_data
; ; Transaction management is handled by caller.
; ;
; ; Input:
; ;   data_ptr (aws_tmp08/09) = buffer address
; ;   Sector info in workspace variables
; ;
; ; Output:
; ;   Data in buffer
; ;   Carry clear on success
; ; ============================================================================
; fn_disk_read_sector_impl:
;         jsr     remember_axy

;         ; Get slot from current drive
;         ; current_drv is 0-based, slots are 1-based
;         lda     current_drv
;         clc
;         adc     #$01            ; Convert to 1-based slot
;         sta     fn_disk_slot

;         ; Get LBA from workspace
;         ; fuji_current_sector contains the sector number
;         lda     fuji_current_sector
;         ldx     fuji_current_sector+1

;         ; Set up buffer pointer
;         lda     data_ptr
;         sta     aws_tmp08
;         lda     data_ptr+1
;         sta     aws_tmp09

;         ; Call the main read function
;         jsr     fn_disk_read_sector

;         rts


; ; ============================================================================
; ; FN_DISK_WRITE_SECTOR - Write a sector to disk
; ;
; ; Request:
; ;   u8  version = 1
; ;   u8  slot
; ;   u32 lba (little-endian)
; ;   u16 dataLen (little-endian)
; ;   u8[] data
; ;
; ; Input:
; ;   A = slot (1-8)
; ;   X/Y = LBA (16-bit sector number)
; ;   aws_tmp08/09 = buffer pointer for data
; ;   aws_tmp02/03 = data length
; ;
; ; Output:
; ;   Carry clear on success, set on error
; ; ============================================================================
; fn_disk_write_sector:
;         ; Save parameters
;         sta     fn_disk_slot
;         stx     aws_tmp00       ; LBA low
;         sty     aws_tmp01       ; LBA high

;         ; Build packet payload
;         ; version(1) + slot(1) + lba(4) + dataLen(2) + data(256) = 264 bytes

;         ; Version
;         lda     #FN_PROTOCOL_VERSION
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+0

;         ; Slot
;         lda     fn_disk_slot
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+1

;         ; LBA (32-bit, little-endian)
;         lda     aws_tmp00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+2
;         lda     aws_tmp01
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+3
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+4
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+5

;         ; Data length = 256 (little-endian)
;         lda     #$00
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+6
;         lda     #$01
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+7

;         ; Copy data from source buffer
;         ldy     #$00
; @copy_data:
;         lda     (aws_tmp08),y
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+8,y
;         iny
;         bne     @copy_data

;         ; Build packet manually (264 bytes doesn't fit in Y)
;         ; Store header manually
;         lda     #FN_DEVICE_DISK
;         sta     fuji_tx_buffer+0
;         lda     #DISK_CMD_WRITE_SECTOR
;         sta     fuji_tx_buffer+1

;         ; Length = 6 (header) + 264 (payload) = 270
;         lda     #<270
;         sta     fuji_tx_buffer+2
;         lda     #>270
;         sta     fuji_tx_buffer+3

;         ; Checksum placeholder
;         lda     #$00
;         sta     fuji_tx_buffer+4

;         ; Descriptor
;         sta     fuji_tx_buffer+5

;         ; Store length
;         lda     #<270
;         sta     fn_tx_len
;         lda     #>270
;         sta     fn_tx_len_hi

;         ; Calculate checksum
;         lda     #<fuji_tx_buffer
;         sta     aws_tmp00
;         lda     #>fuji_tx_buffer
;         sta     aws_tmp01
;         lda     fn_tx_len
;         sta     aws_tmp02
;         lda     fn_tx_len_hi
;         sta     aws_tmp03

;         jsr     _calc_checksum
;         sta     fuji_tx_buffer+4

;         ; Send packet
;         jsr     fn_send_packet
;         bcs     @write_error

;         ; Receive response
;         jsr     fn_receive_packet
;         bcs     @write_error

;         clc
;         rts

; @write_error:
;         sec
;         rts


; ; ============================================================================
; ; FN_DISK_WRITE_SECTOR_IMPL - Low-level write for fuji_serial.s
; ;
; ; This is the implementation function called by fuji_write_block_data
; ; Transaction management is handled by caller.
; ;
; ; Input:
; ;   data_ptr (aws_tmp08/09) = buffer address
; ;   Sector info in workspace variables
; ;
; ; Output:
; ;   Carry clear on success
; ; ============================================================================
; fn_disk_write_sector_impl:
;         jsr     remember_axy

;         ; Get slot from current drive
;         lda     current_drv
;         clc
;         adc     #$01
;         sta     fn_disk_slot

;         ; Get LBA from workspace
;         lda     fuji_current_sector
;         ldx     fuji_current_sector+1

;         ; Set up buffer pointer
;         lda     data_ptr
;         sta     aws_tmp08
;         lda     data_ptr+1
;         sta     aws_tmp09

;         ; Data length = 256
;         lda     #$00
;         sta     aws_tmp02
;         lda     #$01
;         sta     aws_tmp03

;         ; Call the main write function
;         jsr     fn_disk_write_sector

;         rts


; ; ============================================================================
; ; FN_DISK_INFO - Get disk slot information
; ;
; ; Request:
; ;   u8  version = 1
; ;   u8  slot
; ;
; ; Input:
; ;   A = slot (1-8)
; ;
; ; Output:
; ;   fuji_rx_buffer contains response
; ;   Carry clear on success
; ; ============================================================================
; fn_disk_info:
;         pha                     ; Save slot

;         ; Build packet payload
;         lda     #FN_PROTOCOL_VERSION
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+0

;         pla                     ; Get slot
;         sta     fuji_tx_buffer+FN_HEADER_SIZE+1

;         ; Build packet
;         lda     #FN_DEVICE_DISK
;         ldx     #DISK_CMD_INFO
;         ldy     #$02

;         jsr     fn_build_packet

;         ; Send packet
;         jsr     fn_send_packet
;         bcs     @info_error

;         ; Receive response
;         jsr     fn_receive_packet
;         bcs     @info_error

;         clc
;         rts

; @info_error:
;         sec
;         rts
