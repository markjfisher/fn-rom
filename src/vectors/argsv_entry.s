; ARGSV_ENTRY - Arguments Vector
; Handles OSARGS calls for file argument operations
; Translated from MMFS mmfs100.asm lines 4939-4967

        .export argsv_entry
        .export channel_buffer_to_disk_yhandle_a0
        .export channel_buffer_to_disk_yhandle

        .import bput_yintchan
        .import channel_flags_clear_bits
        .import channel_flags_set_bit7
        .import channel_flags_set_bits
        .import check_channel_yhndl_exyintch
        .import close_all_files
        .import close_files_yhandle
        .import err_file_locked
        .import err_file_read_only
        .import print_axy
        .import print_string
        .import remember_axy
        .import return_with_a0
        .import tya_cmp_ptr_ext

        .include "fujinet.inc"

        .segment "CODE"


channel_buffer_to_disk_yhandle_a0:
        jsr     return_with_a0

; Force buffer save for channels
; Y = handle (0 = all files)
channel_buffer_to_disk_yhandle:
        lda     fuji_open_channels      ; Force buffer save - opened channels flag byte
        pha                             ; Save opened channels flag byte
        tya                             ; A=handle
        bne     @chbuf1
        jsr     close_all_files
        beq     @chbuf2                 ; always
@chbuf1:
        jsr     close_files_yhandle
@chbuf2:
        pla                             ; Restore
        sta     fuji_open_channels
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ARGSV_ENTRY - Arguments Vector
; Handles OSARGS calls
; A = action to be taken
; X points to 4 byte area in Zero Page (always i/o processor)
; Y = file handle provided by OSFIND or 0
; Exit:
; X and Y are unchanged
; see 16.1.2 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

argsv_entry:
        dbg_string_axy "ARGSV: "

        jsr     remember_axy
        cmp     #$FF
        beq     channel_buffer_to_disk_yhandle_a0  ; If file(s) to media
        cpy     #$00
        beq     @argsv_y0
        cmp     #$04
        bcs     @argsv_exit              ; If A>=4
        jsr     return_with_a0
        cmp     #$03
        beq     argsv3
        cmp     #$01
        bne     argsv_rdseqptr_or_filelen
        jmp     argsv_write_seq_pointer

@argsv_y0:
        cmp     #$02                    ; If A>=2
        bcs     @argsv_exit
        jsr     return_with_a0
        beq     argsv_filesysnumber     ; If A=0
        lda     #$FF
        sta     $02,x                   ; 4 byte address of
        sta     $03,x                   ; "rest of command line"
        lda     fuji_text_ptr_offset   ; (see *run code)
        sta     $00,x
        lda     fuji_text_ptr_hi
        sta     $01,x
@argsv_exit:
        rts


argsv_filesysnumber:
        ; Return filing system number
        lda     #filesysno
        tsx
        sta     $0105,x
        rts

argsv_rdseqptr_or_filelen:
        jsr     check_channel_yhndl_exyintch    ; A=0 or A=2
        sty     fuji_intch
        asl     a                               ; A=0 or A=4
        adc     fuji_intch
        tay
        lda     fuji_ch_bptr_low,y
        sta     $00,x
        lda     fuji_ch_bptr_mid,y
        sta     $01,x
        lda     fuji_ch_bptr_hi,y
        sta     $02,x
        lda     #$00
        sta     $03,x
        rts

; change EXT of a file
argsv3:
        jsr     check_channel_yhndl_exyintch
        jsr     cmp_to_ext
        bcs     @truncate
        lda     fuji_ch_bptr_low,y
        pha
        lda     fuji_ch_bptr_mid,y
        pha
        lda     fuji_ch_bptr_hi,y
        pha
        jsr     args_ext_end_loop
        pla
        sta     fuji_ch_bptr_hi,y
        pla
        sta     fuji_ch_bptr_mid,y
        pla
        sta     fuji_ch_bptr_low,y
        jsr     is_seq_pointer_in_buffer_yintch
@truncate:
        lda     fuji_ch_name7,y
        bmi     file_read_only
        ora     fuji_ch_dir,y
        bmi     file_locked
        lda     #$20
        jsr     channel_flags_set_bits

        lda     $00,x
        sta     fuji_ch_ext_low,y
        lda     $01,x
        sta     fuji_ch_ext_mid,y
        lda     $02,x
        sta     fuji_ch_ext_hi,y
        txa
        pha
        jsr     tya_cmp_ptr_ext
        pla
        tax
        bcc     @dont_change_ptr
        jsr     set_seq_pointer_yintch
@dont_change_ptr:
        lda     #$EF
        jmp     channel_flags_clear_bits

file_read_only:
        jmp     err_file_read_only

file_locked:
        jmp     err_file_locked

cmp_to_ext:
        lda     fuji_ch_ext_low,y
        cmp     $00,x
        lda     fuji_ch_ext_mid,y
        sbc     $01,x
        lda     fuji_ch_ext_hi,y
        sbc     $02,x
cmp_to_ext_exit:
        rts

argsv_write_seq_pointer:
        jsr     remember_axy
        jsr     check_channel_yhndl_exyintch

wsp_loop:
        jsr     cmp_to_ext
        bcs     set_seq_pointer_yintch

args_ext_end_loop:
        lda     fuji_ch_ext_low,y
        sta     fuji_ch_bptr_low,y
        lda     fuji_ch_ext_mid,y
        sta     fuji_ch_bptr_mid,y
        lda     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_hi,y
        jsr     is_seq_pointer_in_buffer_yintch
        lda     aws_tmp06
        pha
        lda     aws_tmp07
        pha
        lda     aws_tmp08
        pha
        lda     #$00
        jsr     bput_yintchan
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp07
        pla
        sta     aws_tmp06
        jmp     wsp_loop

set_seq_pointer_yintch:
        lda     $00,x
        sta     fuji_ch_bptr_low,y
        lda     $01,x
        sta     fuji_ch_bptr_mid,y
        lda     $02,x
        sta     fuji_ch_bptr_hi,y
        ; fall into is_seq_pointer_in_buffer_yintch

is_seq_pointer_in_buffer_yintch:
        lda     #$6F
        jsr     channel_flags_clear_bits

        lda     fuji_ch_sec_start,y
        adc     fuji_ch_bptr_mid,y
        sta     fuji_channel_block_size

        lda     fuji_ch_op,y
        and     #$03
        adc     fuji_ch_bptr_hi,y
        cmp     fuji_ch_sect_hi,y
        bne     cmp_to_ext_exit

        lda     fuji_channel_block_size
        cmp     fuji_ch_sect_lo,y
        bne     cmp_to_ext_exit
        jmp     channel_flags_set_bit7

