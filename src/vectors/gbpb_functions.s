        .export  gbpb_put_bytes
        .export  gbpb_getbyte_savebyte
        .export  gbpb_get_mediatitle
        .export  gbpb_rd_cur_dir_device
        .export  gbpb_rd_cur_lib_device
        .export  gbpb_rd_file_cur_dir
        .export  gbpb_gosub

        .import  remember_axy
        .import  argsv_rdseqptr_or_filelen
        .import  argsv_write_seq_pointer
        .import  tube_claim

        .import gbpb_load_blkptr
        .import gbpbv_table_hi
        .import gbpbv_table_lo
        .import gbpbv_table3

        .include "fujinet.inc"

; TODO all the GBPBV functions from MMFS

gbpb_put_bytes:
gbpb_getbyte_savebyte:
gbpb_get_mediatitle:
gbpb_rd_cur_dir_device:
gbpb_rd_cur_lib_device:
gbpb_rd_file_cur_dir:

        rts


; ENTRY:
;  y = gbpb command
gbpb_gosub:
        lda     gbpbv_table_lo, y
        sta     fuji_param_block_lo
        lda     gbpbv_table_hi, y
        sta     fuji_param_block_hi
        lda     gbpbv_table3, y
        lsr     a
        php                                     ; storing bit 0 as C flag into stack
        lsr     a
        php                                     ; storing bit 1 as C flag into stack
        sta     fuji_gbpbv_tube_op

; TODO: do we want to make option to NOT use fastgbp?
; if so, we have some changes to do, and load the blk pointer into ZP here

        ldy     #$0C
@gbpb_ctlblk_loop:
        lda     (aws_tmp04), y          ; NOTE: if atemp changes in fastgb, this will need to be fixed
        sta     gbpb_buf_0c, y
        dey
        bpl     @gbpb_ctlblk_loop

; DFS 2.45 9E30
        lda     gbpb_buf_0c+3
        and     gbpb_buf_0c+4
        ora     fuji_tube_present
        clc
        adc     #$01
        beq     @gbpb_nottube1

        jsr     tube_claim
        clc

        lda     #$FF
@gbpb_nottube1:
        sta     gbpb_tube
        lda     fuji_gbpbv_tube_op
        bcs     @gbpb_nottube2
        ldx     #$61
        ldy     #$10                    ; NOTE: TODO: MMFS uses #MP + &10, but we don't have MP setup yet, as it's MASTER and other hardware support

        jsr     tube_code

@gbpb_nottube2:
        plp                             ; read bits back off the stack from earlier from gbpbv_table3
        bcs     gbpb_rw_seqptr          ; bit 1 was SET from the data, which is "transfer data"
        plp                             ; not set, so read bit 0, which is preserving PTR into Carry

gbpb_jmpsub:
        jmp     (fuji_param_block_lo)

gbpb_rw_seqptr:
        ldx     #$03
@gbpb_seqptr_loop1:
        lda     gbpb_seqptr, x          ; !B6 = ctrl block seq ptr, which is a 4 byte pling
        sta     aws_tmp06, x
        dex
        bpl     @gbpb_seqptr_loop1

        ldx     #$B6                    ; is this aws_tmp06 low address? although X is usually high byte
        ldy     gbpb_file_handle
        lda     #$00
        plp                             ; "bit 0" from table3, which is "preserving PTR" if set to 1
        bcs     @gpbp_dont_write_seqptr
        jsr     argsv_write_seq_pointer

@gpbp_dont_write_seqptr:
        jsr     argsv_rdseqptr_or_filelen

        ldx     #$03
@gbpb_seqptr_loop2:
        lda     aws_tmp06, x            ; ctrl blk seq ptr = !b6, opposite of the above
        sta     gbpb_seqptr, x
        dex
        bpl     @gbpb_seqptr_loop2

gbpb_rwdata:
        jsr     gbpb_bytes_xfer_invert  ; returns with N=1
        bmi     @gbpb_data_loopin        ; always

@gbpb_data_loop:
        ldy     gbpb_file_handle
        jsr     gbpb_jmpsub
        bcs     @gbpb_data_loopout

        ldx     #$09                    ; 9-C
        jsr     gbpb_inc_dbl_word_buf_x
@gbpb_data_loopin:
        ldx     #$05                    ; 5-8
        jsr     gbpb_inc_dbl_word_buf_x
        bne     @gbpb_data_loop

        clc
@gbpb_data_loopout:
        php
        jsr     gbpb_bytes_xfer_invert
        ldx     #$05                    ; 5-8
        jsr     gbpb_inc_dbl_word_buf_x

        jsr     gbpb_load_blkptr
        ldy     #$0C
@gbpb_restore_ctl_blk_loop:
        lda     gbpb_buf_0c, y
        sta     (aws_tmp04), y
        dey
        bpl     @gbpb_restore_ctl_blk_loop
        plp                                     ; C=1 means transfer not completed
        rts

gbpb_inc_data_ptr:
        jsr     remember_axy
        ldx     #$01

gbpb_inc_dbl_word_buf_x:
        ldy     #$04

@gbpb_inc_dbl_word_loop:
        inc     gbpb_buf_0c, x
        bne     @gbpb_inc_dbl_word_exit
        inx
        dey
        bne     @gbpb_inc_dbl_word_loop

@gbpb_inc_dbl_word_exit:
        rts

gbpb_bytes_xfer_invert:
        ldx     #$03                            ; bytes to transfer XOR $FFFF
@gbpb_bytes_xfer_invert_loop:
        lda     #$FF
        eor     gbpb_buf_0c+5, x
        sta     gbpb_buf_0c+5, x
        dex
        bpl     @gbpb_bytes_xfer_invert_loop
        rts
