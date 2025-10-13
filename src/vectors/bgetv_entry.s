; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls for reading single bytes from files
; Translated from MMFS mmfs100.asm lines 5169-5195

        .export bgetv_entry

        .import calc_buffer_sector_for_ptr
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch_tya_cmpptr
        .import LoadMemBlock
        .import SaveMemBlock
        .import print_axy
        .import print_string
        .import print_hex
        .import print_newline
        .import remember_axy
        .import remember_xy_only
        .import report_error_cb

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
        ;dbg_string_axy "BGETV: "

        jsr     remember_xy_only
        jsr     check_channel_yhndl_exyintch_tya_cmpptr  ; A=Y

        bne     @bg_not_eof              ; If PTR<>EXT
        lda     fuji_ch_flg,y            ; Already at EOF?
        and     #$10
        bne     @err_eof                 ; IF bit 4 set
        lda     #$10
        jsr     channel_flags_set_bits   ; Set bit 4
        ldx     fuji_saved_x
        lda     #$FE

        dbg_string_axy "exiting bgetv_entry:"

        sec
        rts                              ; C=1=EOF

@bg_not_eof:
        dbg_string_axy "bgnoteof:"

        lda     fuji_ch_flg,y
        bmi     @bg_samesector1          ; If buffer ok
        jsr     channel_set_dir_drive_yintch
        jsr     channel_buffer_to_disk_yintch  ; Save buffer
        sec
        jsr     channel_buffer_rw_yintch_c1read  ; Load buffer

@bg_samesector1:
        jsr     load_then_inc_seq_ptr_yintch  ; load buffer ptr into BA/BB then increments Seq Ptr
        lda     (aws_tmp10, x)          ; Byte from buffer

.ifdef FN_DEBUG
        ; Debug: show what byte we just read
        pha
        jsr     print_string
        .byte   "Read b: $"
        nop
        pla
        pha
        jsr     print_hex
        jsr     print_newline

        pla
.endif

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
        inc     fuji_error_flag         ; Remember in case of error (MMFS line 5231)
        ldy     fuji_intch              ; Setup NMI vars (MMFS line 5232)
        lda     fuji_ch_buf_page,y      ; Buffer page (MMFS line 5233)
        sta     aws_tmp13               ; Data ptr high byte (MMFS line 5234)
        lda     #$FF                    ; Set load address to host (MMFS line 5235)
        sta     fuji_buf_1074           ; (MMFS line 5236)
        sta     fuji_buf_1075           ; (MMFS line 5237)
        lda     #$00                    ; (MMFS line 5238)
        sta     aws_tmp12               ; Data ptr low byte (MMFS line 5239)
        sta     pws_tmp00               ; Sector (MMFS line 5240)
        lda     #$01                    ; (MMFS line 5241)
        sta     pws_tmp01               ; (MMFS line 5242)
        bcs     chnbuf_read             ; IF c=1 load buffer else save (MMFS line 5243)
        lda     fuji_ch_sect_lo,y       ; Buffer sector (MMFS line 5244)
        sta     pws_tmp03               ; Start sec. b0-b7 (&C3) (MMFS line 5245)
        lda     fuji_ch_sect_hi,y       ; (MMFS line 5246)
        sta     pws_tmp02               ; "mixed byte" (&C2) (MMFS line 5247)
        jsr     SaveMemBlock            ; (MMFS line 5248)
        ldy     fuji_intch              ; Y=intch (MMFS line 5249)
        lda     #$BF                    ; Clear bit 6 (MMFS line 5250)
        jsr     channel_flags_clear_bits ; (MMFS line 5251)
        bcc     chnbuf_exit             ; always (MMFS line 5252)
chnbuf_read:
        dbg_string_axy "chnbuf_read called"
        jsr     calc_buffer_sector_for_ptr ; Calculate which sector to load
        dbg_string_axy "calc_buffer_sector done"
        jsr     LoadMemBlock               ; Load buffer (high-level interface)
        dbg_string_axy "LoadMemBlock done"

chnbuf_exit:
        dec     fuji_error_flag         ; MMFS line 5257
        ldy     fuji_intch              ; Y=intch (MMFS line 5258)
        rts

load_then_inc_seq_ptr_yintch:
        ; Load buffer pointer into BA/BB then increment sequence pointer
        lda     fuji_ch_bptr_low,y      ; Seq.Ptr
        sta     aws_tmp10               ; BA
        lda     fuji_ch_buf_page,y      ; Buffer page
        sta     aws_tmp11               ; BB

.ifdef FN_DEBUG
        pha
        ; Debug: show what address we're about to read from
        jsr     print_string
        .byte   "Reading from: $"
        lda     aws_tmp11
        jsr     print_hex
        lda     aws_tmp10
        jsr     print_hex
        jsr     print_newline
        pla
.endif

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

