; FujiNet file system operations
; High-level disk operations equivalent to MMC.asm
; Adapted for network operations via FujiNet

        .export fuji_init
        .export fuji_read_block
        .export fuji_write_block
        .export fuji_read_catalog
        .export fuji_write_catalog
        .export fuji_read_disc_title
        .export fuji_begin_transaction
        .export fuji_end_transaction
        .export fuji_check_device_status
        .export fuji_read_mem_block
        .export fuji_write_mem_block

        .import print_string
        .import err_disk
        .import remember_axy
        .import fuji_read_block_data
        .import fuji_write_block_data
        .import fuji_read_catalog_data
        .import fuji_write_catalog_data
        .import fuji_read_disc_title_data
        .import fuji_execute_block_rw

        .include "fujinet.inc"

        .segment "CODE"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_INIT - Initialize FujiNet device
; Carry=0 if ok, Carry=1 if device doesn't respond
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_init:
        ldx     #$00
        stx     fuji_state
        stx     fuji_current_disk
        
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
; FUJI_READ_BLOCK - Read data block from network
; at loc. datptr, sec, seccount & byteslastsec define block
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_block:
        jsr     remember_axy
        jsr     fuji_begin_transaction
        jsr     fuji_read_block_data
        jmp     fuji_end_transaction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK - Write data block to network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block:
        jsr     remember_axy
        jsr     fuji_begin_transaction
        jsr     fuji_write_block_data
        jmp     fuji_end_transaction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fuji_read_catalog - Read the disc catalog (512-byte directory)
; The catalog contains:
; - Bytes 0-7: Disc title (first 8 chars)
; - Bytes 248-255: Disc title (last 8 chars, if title > 8 chars)
; - Bytes 8-247: File directory entries (8 bytes each)
; - Each file entry: filename, load/exec addresses, length, attributes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalog:
        jsr     remember_axy
        jsr     fuji_begin_transaction

        ; Set up catalog buffer at page 0x0E (512 bytes)
        lda     #$00
        sta     data_ptr
        lda     #$0E                    ; Catalogue buffer at page 0x0E
        sta     data_ptr+1

        ; For FujiNet, we need to request the disc catalog from the network
        ; This is NOT reading physical sectors - it's requesting directory info
        ; TODO: Implement network request for disc catalog
        ; For now, this is a placeholder that would:
        ; 1. Send "GET_CATALOGUE" command to FujiNet
        ; 2. Receive 512-byte catalog data
        ; 3. Store it in the buffer at 0x0E00-0x0FFF

        jsr     fuji_read_catalog_data
        jmp     fuji_end_transaction

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
        ; TODO: Implement network request to update disc catalog
        ; For now, this is a placeholder that would:
        ; 1. Send "PUT_CATALOG" command to FujiNet
        ; 2. Send 512-byte catalog data from buffer 0x0E00-0x0FFF
        ; 3. Confirm successful update

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
        ; TODO: Implement network request for disc title
        ; For now, this is a placeholder that would:
        ; 1. Send "GET_DISC_TITLE" command to FujiNet
        ; 2. Receive disc title string (up to 16 chars)
        ; 3. Store it in the buffer at 0x1000-0x100F

        jsr     fuji_read_disc_title_data
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_BEGIN_TRANSACTION - Begin FujiNet transaction
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_begin_transaction:
        ; Save workspace variables
        ldx     #$0F
@save_loop:
        lda     aws_tmp12,x
        sta     $1090,x
        dex
        bpl     @save_loop

        ; Check if FujiNet initialized
        bit     fuji_state
        bvs     @already_init

        ; Initialize if needed
        jsr     fuji_init
        bcs     @init_failed

        ; Check device status
        jsr     fuji_check_device_status
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
        ; Restore workspace variables
        ldx     #$0F
@restore_loop:
        lda     $1090,x
        sta     aws_tmp12,x
        dex
        bpl     @restore_loop
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
        lda     #$85                     ; Read operation
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
        lda     #$A5                     ; Write operation
        jsr     fuji_execute_block_rw
        jsr     fuji_end_transaction     ; Restore &BC-&CB
        lda     #1                       ; Success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATA LAYER FUNCTIONS
; These are implemented in fuji_serial.s (or other interface modules)
; The function names are implementation-agnostic
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; These functions are implemented in the interface layer:
; - fuji_read_block_data
; - fuji_write_block_data  
; - fuji_read_catalog_data
; - fuji_write_catalog_data
; - fuji_read_disc_title_data