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

        .include "mos.inc"
        .include "fujinet.inc"

        .segment "CODE"

; Network protocol constants will be defined in fuji_serial.s

; FujiNet state variables
fuji_state                     = $10E0  ; Device state
fuji_current_disk              = $10E1  ; Current mounted disk

; Sector and data pointers (using existing MMFS variables)
; sec = aws_tmp02 (3-byte sector number)
; seccount = aws_tmp05 (2-byte sector count)  
; byteslastsec = aws_tmp07 (bytes in last sector)
; datptr = aws_tmp08 (2-byte data pointer)

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
        jsr     fuji_serial_read_block
        jmp     fuji_end_transaction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_BLOCK - Write data block to network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_block:
        jsr     remember_axy
        jsr     fuji_begin_transaction
        jsr     fuji_serial_write_block
        jmp     fuji_end_transaction

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_CATALOGUE - Read the catalogue (sectors 0xE and 0xF)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_catalogue:
        ; Set up catalogue sectors (0xE and 0xF)
        lda     #$00
        sta     aws_tmp08
        lda     #$0E                    ; Catalogue at page 0x0E
        sta     aws_tmp09
        
        ; Read 2 sectors (512 bytes) for catalogue
        lda     #$0E                    ; Start sector
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        sta     aws_tmp04
        lda     #$02                    ; 2 sectors
        sta     aws_tmp05
        lda     #$00
        sta     aws_tmp06
        
        jsr     fuji_read_block
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_WRITE_CATALOGUE - Write the catalogue
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_write_catalogue:
        ; Set up catalogue sectors (0xE and 0xF)
        lda     #$00
        sta     aws_tmp08
        lda     #$0E                    ; Catalogue at page 0x0E
        sta     aws_tmp09
        
        ; Write 2 sectors (512 bytes) for catalogue
        lda     #$0E                    ; Start sector
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        sta     aws_tmp04
        lda     #$02                    ; 2 sectors
        sta     aws_tmp05
        lda     #$00
        sta     aws_tmp06
        
        jsr     fuji_write_block
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_READ_DISC_TITLE - Read disc title from first sector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_read_disc_title:
        ; Set up sector 0
        lda     #$00
        sta     aws_tmp02
        sta     aws_tmp03
        sta     aws_tmp04
        
        ; Set up buffer for disc title
        lda     #$00
        sta     aws_tmp08
        lda     #$10                    ; Buffer at page 0x10
        sta     aws_tmp09
        
        ; Read 1 sector
        lda     #$01
        sta     aws_tmp05
        lda     #$00
        sta     aws_tmp06
        
        jsr     fuji_read_block
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FUJI_BEGIN_TRANSACTION - Begin FujiNet transaction
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fuji_begin_transaction:
        ; Save workspace variables
        ldx     #$0F
@save_loop:
        lda     $BC,x
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
        sta     $BC,x
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
; SERIAL LAYER FUNCTIONS
; These will be implemented in fuji_serial.s
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Placeholder functions - to be implemented in fuji_serial.s
fuji_serial_read_block:
        ; TODO: Read block from FujiNet via serial
        rts

fuji_serial_write_block:
        ; TODO: Write block to FujiNet via serial
        rts