; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls for reading single bytes from files
; Translated from MMFS mmfs100.asm lines 5169-5195

        .export bgetv_entry

        .import check_channel_yhndl_exyintch_tya_cmpptr
        .import print_axy
        .import print_string
        .import remember_axy
        .import report_error_cb

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bgetv_entry:
        dbg_string_axy "BGETV: "
        ; rts

        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch_tya_cmpptr  ; A=Y
        bne     @bg_not_eof              ; If PTR<>EXT
        lda     fuji_1117,y   ; Already at EOF?
        and     #$10
        bne     @err_eof                 ; IF bit 4 set
        lda     #$10
        jsr     channel_flags_set_bits   ; Set bit 4
        ldx     fuji_saved_x
        lda     #$FE
        sec
        rts                             ; C=1=EOF

@bg_not_eof:
        lda     fuji_1117,y
        bmi     @bg_samesector1          ; If buffer ok
        jsr     channel_set_dir_drive_yintch
        jsr     channel_buffer_to_disk_yintch  ; Save buffer
        sec
        jsr     channel_buffer_rw_yintch_c1read  ; Load buffer

@bg_samesector1:
        jsr     load_then_inc_seq_ptr_yintch  ; load buffer ptr into BA/BB then increments Seq Ptr
        lda     (aws_tmp10, x)          ; Byte from buffer
        clc
        rts                             ; C=0=NOT EOF

@err_eof:
        jsr     report_error_cb
        .byte   $DF
        .byte   "EOF",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

channel_flags_set_bits:
        ; TODO: Implement channel flags setting
        rts

channel_set_dir_drive_yintch:
        ; TODO: Implement channel directory/drive setting
        rts

channel_buffer_to_disk_yintch:
        ; TODO: Implement channel buffer to disk
        rts

channel_buffer_rw_yintch_c1read:
        ; TODO: Implement channel buffer read/write
        rts

load_then_inc_seq_ptr_yintch:
        ; TODO: Implement load and increment sequence pointer
        rts
