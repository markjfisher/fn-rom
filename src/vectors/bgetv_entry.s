; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls for reading single bytes from files
; Translated from MMFS mmfs100.asm lines 5169-5195

        .export bgetv_entry

        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch_tya_cmpptr
        .import print_axy
        .import print_string
        .import remember_axy
        .import report_error_cb
        .import a_rolx5

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls
; Y = file handle provided by OSFIND
; Exit:
; A = byte read
; C = 0 if not EOF, 1 if EOF
; X and Y are unchanged
; see 16.1.3 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

bgetv_entry:
        dbg_string_axy "BGETV: "
        ; rts

        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch_tya_cmpptr  ; A=Y
        bne     @bg_not_eof              ; If PTR<>EXT
        lda     fuji_ch_flg,y            ; Already at EOF?
        and     #$10
        bne     @err_eof                 ; IF bit 4 set
        lda     #$10
        jsr     channel_flags_set_bits   ; Set bit 4
        ldx     fuji_saved_x
        lda     #$FE
        sec
        rts                              ; C=1=EOF

@bg_not_eof:
        lda     fuji_ch_flg,y
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
        ; Set bits in channel flags (A contains bits to set)
        ora     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        clc
        rts

channel_buffer_to_disk_yintch:
        ; Save channel buffer to disk
        lda     fuji_ch_flg,y
        and     #$40                    ; Bit 6 set?
        beq     chnbuf_exit2            ; If no exit
        clc                             ; C=0=write buffer
        ; TODO: Implement buffer save for FujiNet
chnbuf_exit2:
        rts

channel_buffer_rw_yintch_c1read:
        ; Read/write channel buffer
        ; C=1 for read, C=0 for write
        bcs     chnbuf_read             ; IF c=1 load buffer else save
        ; TODO: Implement buffer save for FujiNet
        ldy     fuji_intch            ; Y=intch
        lda     #$BF                    ; Clear bit 6
        jsr     channel_flags_clear_bits
        bcc     chnbuf_exit             ; always
chnbuf_read:
        jsr     calc_buffer_sector_for_ptr ; sets NMI data ptr
        ; TODO: Implement buffer load for FujiNet
chnbuf_exit:
        ldy     fuji_intch            ; Y=intch
        rts

load_then_inc_seq_ptr_yintch:
        ; Load buffer pointer into BA/BB then increment sequence pointer
        lda     fuji_ch_bptr_low,y      ; Seq.Ptr
        sta     aws_tmp10               ; BA
        lda     fuji_ch_buf_page,y      ; Buffer page
        sta     aws_tmp11               ; BB
        tya
        tax
        inc     fuji_ch_bptr_low,x      ; Seq.Ptr+=1
        bne     samesector
        jsr     channel_flags_clear_bit7 ; PTR in new sector!
        inc     fuji_ch_bptr_mid,x
        bne     samesector
        inc     fuji_ch_bptr_hi,x
samesector:
        ldx     #$00
        rts

channel_flags_clear_bit7:
        lda     #$7F                    ; Clear bit 7
        and     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        clc
        rts

channel_flags_clear_bits:
        and     fuji_ch_flg,y
        sta     fuji_ch_flg,y
        clc
        rts

calc_buffer_sector_for_ptr:
        ; Calculate buffer sector for PTR
        clc
        lda     aws_tmp15,y             ; Start Sector + Seq Ptr
        adc     fuji_ch_bptr_mid,y
        sta     aws_tmp15               ; C3
        sta     fuji_ch_buf_page,y      ; Buffer sector
        lda     aws_tmp13,y
        and     #$03
        adc     fuji_ch_bptr_hi,y
        sta     aws_tmp14               ; C2
        sta     fuji_ch_buf_page,y      ; Buffer sector high
        rts
