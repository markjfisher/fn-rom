; BGETV_ENTRY - Byte Get Vector
; Handles BGET calls for reading single bytes from files
; Translated from MMFS mmfs100.asm lines 5169-5195

        .export bgetv_entry
        .export channel_buffer_rw_yintch_c1read
        .export channel_buffer_to_disk_yintch
        .export load_then_inc_seq_ptr_yintch

        .import calc_buffer_sector_for_ptr
        .import channel_flags_set_bits
        .import channel_set_dir_drive_yintch
        .import check_channel_yhndl_exyintch_tya_cmpptr
        .import load_mem_block
        .import save_mem_block
        .import print_newline
        .import print_string
        .import print_hex
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
        jsr     check_channel_yhndl_exyintch_tya_cmpptr         ; exits with comparison between PTR and EXT to check if we're at EOF, and Y=intch

        bne     @bg_not_eof              ; If PTR<>EXT
        lda     fuji_ch_flg,y            ; Already at EOF?
        and     #$10
        bne     @err_eof                 ; IF bit 4 set
        lda     #$10
        jsr     channel_flags_set_bits   ; Set bit 4
        ldx     fuji_saved_x
        lda     #$FE

        ; dbg_string_axy "exiting bgetv_entry:"

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

        ; THIS IS THE MAIN READ OF THE DATA BYTE INTO A
        ; X is always 0 at this point from previous subroutine
        lda     (aws_tmp10, x)          ; Byte from buffer

        clc
        rts                             ; C=0 => NOT EOF

@err_eof:
        jsr     report_error_cb
        .byte   $DF
        .byte   "EOF",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


channel_buffer_to_disk_yintch:
        ; Save channel buffer to disk (MMFS lines 5223-5228)
.ifdef FN_DEBUG_WRITE_DATA
        pha
        jsr     print_string
        .byte   "BufToDisk: flg=$"
        lda     fuji_ch_flg,y
        jsr     print_hex
        jsr     print_newline
        pla
.endif
        lda     fuji_ch_flg,y
        and     #$40                    ; Bit 6 set?
        beq     chnbuf_exit2            ; If no exit
        clc                             ; C=0=write buffer
        ; Fall through to channel_buffer_rw_yintch_c1read

channel_buffer_rw_yintch_c1read:
        ; Read/write channel buffer
        ; C=1 for read, C=0 for write
        inc     fuji_error_flag         ; Remember in case of error
        ldy     fuji_intch              ; Setup NMI vars
        lda     fuji_ch_buf_page,y      ; Buffer page
        sta     aws_tmp13               ; Data ptr high byte
        lda     #$FF                    ; Set load address to host
        sta     fuji_filev_load_hi
        sta     fuji_filev_load_hi+1
        lda     #$00
        sta     aws_tmp12               ; Data ptr low byte
        sta     pws_tmp00               ; Sector
        lda     #$01
        sta     pws_tmp01
        bcs     chnbuf_read             ; IF c=1 load buffer else save
        lda     fuji_ch_sect_lo,y       ; Buffer sector
        sta     pws_tmp03               ; Start sec. b0-b7 (&C3)
        lda     fuji_ch_sect_hi,y
        sta     pws_tmp02               ; "mixed byte" (&C2)
        jsr     save_mem_block
        ldy     fuji_intch              ; Y=intch
        lda     #$BF                    ; Clear bit 6
        jsr     channel_flags_clear_bits
        bcc     chnbuf_exit             ; always
chnbuf_read:
        jsr     calc_buffer_sector_for_ptr      ; Calculate which sector to load
        jsr     load_mem_block                  ; Load buffer (high-level interface)

chnbuf_exit:
        dec     fuji_error_flag
        ldy     fuji_intch
chnbuf_exit2:
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

