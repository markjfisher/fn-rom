; FujiNet file system operations
; High-level disk operations equivalent to MMC.asm
; Adapted for network operations via FujiNet

        .export fuji_init
        .export fuji_read_block
        .export fuji_write_block
        .export fuji_read_catalogue
        .export fuji_write_catalogue
        .export fuji_read_disc_title
        .export fuji_begin_transaction
        .export fuji_end_transaction
        .export fuji_check_device_status

        .import print_string
        .import print_hex
        .import print_newline
        .import err_disk
        .import err_bad
        .import reset_leds
        .import remember_axy
        .import a_rorx4
        .import fuji_read_block_data
        .import fuji_write_block_data
        .import fuji_read_catalogue_data
        .import fuji_write_catalogue_data
        .import fuji_read_disc_title_data

        .include "fujinet.inc"

        .segment "CODE"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_INIT - Initialize FujiNet device
; Carry=0 if ok, Carry=1 if device doesn't respond
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_init:
        lda     #$00
        sta     fuji_state
        sta     fuji_current_disk

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
; FUJI_READ_CATALOGUE - Read the disc catalogue (512-byte directory)
; The catalogue contains:
; - Bytes 0-7: Disc title (first 8 chars)
; - Bytes 248-255: Disc title (last 8 chars, if title > 8 chars)
; - Bytes 8-247: File directory entries (8 bytes each)
; - Each file entry: filename, load/exec addresses, length, attributes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalogue:
        ; Set up catalogue buffer at page 0x0E (512 bytes)
        lda     #$00
        sta     data_ptr
        lda     #$0E                    ; Catalogue buffer at page 0x0E
        sta     data_ptr+1
        
        ; For FujiNet, we need to request the disc catalogue from the network
        ; This is NOT reading physical sectors - it's requesting directory info
        ; TODO: Implement network request for disc catalogue
        ; For now, this is a placeholder that would:
        ; 1. Send "GET_CATALOGUE" command to FujiNet
        ; 2. Receive 512-byte catalogue data
        ; 3. Store it in the buffer at 0x0E00-0x0FFF
        
        jsr     fuji_read_catalogue_data
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOGUE - Write the disc catalogue back to network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalogue:
        ; Set up catalogue buffer at page 0x0E (512 bytes)
        lda     #$00
        sta     data_ptr
        lda     #$0E                    ; Catalogue buffer at page 0x0E
        sta     data_ptr+1
        
        ; For FujiNet, we need to send the updated catalogue to the network
        ; This is NOT writing physical sectors - it's updating directory info
        ; TODO: Implement network request to update disc catalogue
        ; For now, this is a placeholder that would:
        ; 1. Send "PUT_CATALOGUE" command to FujiNet
        ; 2. Send 512-byte catalogue data from buffer 0x0E00-0x0FFF
        ; 3. Confirm successful update
        
        jsr     fuji_write_catalogue_data
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE - Read disc title from catalogue
; For FujiNet, this reads the disc title from the catalogue buffer
; (bytes 0-7 and 248-255 of the 512-byte catalogue)
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
; DATA LAYER FUNCTIONS
; These are implemented in fuji_serial.s (or other interface modules)
; The function names are implementation-agnostic
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; These functions are implemented in the interface layer:
; - fuji_read_block_data
; - fuji_write_block_data  
; - fuji_read_catalogue_data
; - fuji_write_catalogue_data
; - fuji_read_disc_title_data