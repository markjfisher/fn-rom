; FujiNet file system operations
; High-level disk operations equivalent to MMC.asm
; Adapted for network operations via FujiNet

        .export fuji_begin_transaction
        .export fuji_check_device_status
        .export fuji_end_transaction
        .export fuji_read_catalog
        .export fuji_read_disc_title
        .export fuji_read_mem_block
        .export fuji_write_catalog
        .export fuji_write_mem_block

        .importzp aws_tmp12

        .importzp data_ptr

        .import err_disk
        .import fuji_buf_ws_tmp_buf
        .import fuji_drive_disk_map
        .import fuji_execute_block_rw
        .import fuji_read_catalog_data
        .import fuji_read_disc_title_data
        .import fuji_saved_i
        .import fuji_set_disk_slot_from_mapping_or_error
        .import fuji_state
        .import fuji_write_catalog_data
        .import remember_axy
        .import remember_xy_only
        .import MA
        .import MP: zeropage    ; this is the address size, not that it's in ZP, just ca65 syntax for "8 bit value"

        .include "fujinet.inc"

        .segment "CODE"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; init_state - Initialize FujiNet device
; Carry=0 if ok, Carry=1 if device doesn't respond
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_state:
        ldx     #$00
        stx     fuji_state
        ; stx     fuji_current_disk
        
        ; Initialize drive-to-disk mapping (all unmounted)
        dex                             ; $FF = no disk mounted
        stx     fuji_drive_disk_map+0   ; Drive 0
        stx     fuji_drive_disk_map+1   ; Drive 1
        stx     fuji_drive_disk_map+2   ; Drive 2
        stx     fuji_drive_disk_map+3   ; Drive 3

        ; TODO - check if device is responding
        jsr     fuji_check_device_status
        bcs     @init_failed

        ; Device initialized successfully
        lda     #$40
        sta     fuji_state
        clc
        rts

@init_failed:
        jsr     err_disk
        .byte   $FF
        .byte   "FujiNet device not responding", 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_catalog - Read the disc catalog (512-byte directory)
; The catalog contains:
; - Bytes 0-7: Disc title (first 8 chars)
; - Bytes 248-255: Disc title (last 8 chars, if title > 8 chars)
; - Bytes 8-247: File directory entries (8 bytes each)
; - Each file entry: filename, load/exec addresses, length, attributes
; Exit: A=FF for error, 00 for ok.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog:
        jsr     remember_xy_only
        jsr     fuji_begin_transaction

        ; Set up catalog buffer at page 0x0E (512 bytes)
        lda     #$00
        sta     data_ptr
        lda     #(MP+$0E)                      ; Catalogue buffer at page 0x0E
        sta     data_ptr+1

        ; look up the current drive's slot from table, and save it to fuji_disk_slot.
        ; The returned result is the slot number that was read.
        ; If there is no slot allocated, then we return FF in A (from the slot number), and no read is performed
        jsr     fuji_set_disk_slot_from_mapping_or_error
        bmi     @error_no_slot
        jsr     fuji_read_catalog_data

        ; fall through to exit
        lda     #$00
@error_no_slot:
        pha
        jsr     fuji_end_transaction
        pla
        rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_catalog - Write the disc catalog back to network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalog:
        jsr     remember_axy
        jsr     fuji_begin_transaction

        ; Set up catalog buffer at page 0x0E (512 bytes)
        lda     #$00
        sta     data_ptr
        lda     #$0E                    ; Catalog buffer at page 0x0E
        sta     data_ptr+1

        ; For FujiNet, we need to send the updated catalog to the network
        ; This is NOT writing physical sectors - it's updating directory info
        jsr     fuji_write_catalog_data
        jmp     fuji_end_transaction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE - Read disc title from catalog
; For FujiNet, this reads the disc title from the catalog buffer
; (bytes 0-7 and 248-255 of the 512-byte catalog)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_disc_title:
        ; Set up buffer for disc title (16 bytes max)
        lda     #$00
        sta     data_ptr
        lda     #$10                    ; Buffer at page 0x10
        sta     data_ptr+1

        ; For FujiNet, we need to request just the disc title
        ; This is NOT reading a physical sector - it's requesting title info
        jsr     fuji_read_disc_title_data
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_BEGIN_TRANSACTION - Begin FujiNet transaction
; this is the equivalent of MMC_BEGIN1 which stores data into 1090-109f for _MM32_
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_begin_transaction:
        ; Some entry paths (e.g. shift-boot) arrive with IRQs disabled.
        ; FujiBus RS423 I/O relies on OS buffering/servicing, so temporarily
        ; enable IRQs for the duration of the transaction and restore on exit.
        php
        pla
        and     #$04                    ; I flag bit
        sta     fuji_saved_i
        cli

        ; jsr     set_fuji_data_buffer_ptr

        ; Save workspace variables - this is saving $BC-$CB (aws_tmp12-15 & pws_tmp00-11) into 1090-109f
        ; At least *RUN fails if this isn't done. ARCHITECTURE doc suggests which values are needed to be restored.
        ldx     #$0F
@save_loop:
        lda     aws_tmp12,x
        sta     fuji_buf_ws_tmp_buf,x
        dex
        bpl     @save_loop

        ; Check if FujiNet initialized
        bit     fuji_state
        bvs     @already_init

        ; Initialize if needed
        jsr     init_state
        bcs     @init_failed

@already_init:
        rts

@init_failed:
        jsr     err_disk
        .byte   $FF
        .byte   "FujiNet device error", 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_END_TRANSACTION - End FujiNet transaction
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_end_transaction:

        ; Restore workspace variables from 1090-109F into BC-CB
        ; we don't reach into 10A0
        ldx     #$0F
@restore_loop:
        lda     fuji_buf_ws_tmp_buf,x
        sta     aws_tmp12,x
        dex
        bpl     @restore_loop

        ; Restore original IRQ-disable state without disturbing other flags
        ; (e.g. carry from the wrapped operation).
        lda     fuji_saved_i
        bne     @restore_sei
        cli
        rts

@restore_sei:
        sei
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_CHECK_DEVICE_STATUS - Check if FujiNet device is responding
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_check_device_status:
        ; TODO: Send status command to FujiNet
        ; This would send a status request and check response
        ; For now, assume device is always available
        clc
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_mem_block - Read memory block with transaction protection
; This is the proper interface for load_mem_block to call
; Wraps fuji_execute_block_rw with transaction management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_mem_block:
        jsr     fuji_begin_transaction   ; Save &BC-&CB
        lda     #$85                     ; Read operation - TODO: This is very MMFS based for the value
        jsr     fuji_execute_block_rw
        jsr     fuji_end_transaction     ; Restore &BC-&CB
        lda     #1                       ; Success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_write_mem_block - Write memory block with transaction protection
; This is the proper interface for save_mem_block to call
; Wraps fuji_execute_block_rw with transaction management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_mem_block:
        jsr     fuji_begin_transaction   ; Save &BC-&CB
        lda     #$A5                     ; Write operation - TODO: This is very MMFS based for the value
        jsr     fuji_execute_block_rw
        jsr     fuji_end_transaction     ; Restore &BC-&CB
        lda     #1                       ; Success
        rts
