        .export  gbpb_put_bytes
        .export  gbpb_getbyte_savebyte
        .export  gbpb5_get_mediatitle
        .export  gbpb6_rd_cur_dir_device
        .export  gbpb7_rd_cur_lib_device
        .export  gbpb8_rd_file_cur_dir
        .export  gbpb_gosub

        .import  remember_axy
        .import  is_alpha_char
        .import  a_rorx4
        .import  y_add8

        .import  argsv_rdseqptr_or_filelen
        .import  argsv_write_seq_pointer
        .import  set_curdirdrv_to_defaults_check_cur_drv_cat

        .import  tube_claim

        .import  gbpb_load_blkptr
        .import  gbpbv_table_hi
        .import  gbpbv_table_lo
        .import  gbpbv_table3

        .import  bgetv_entry
        .import  bputv_entry

        .include "fujinet.inc"

gbpb_put_bytes:
        jsr     @gbpb_pb_loadbyte
        jsr     bputv_entry
        clc
        rts

@gbpb_pb_loadbyte:
        bit     gbpb_tube
        bpl     @gbpb_pb_fromhost
        lda     TUBE_R3_DATA
        jmp     gbpb_inc_data_ptr

@gbpb_pb_fromhost:
        jsr     gbpb_b8_memptr
        lda     (aws_tmp08, x)                  ; wow, first time using this type of indirection
        jmp     gbpb_inc_data_ptr


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
        bcs     @gbpb_dont_write_seqptr
        jsr     argsv_write_seq_pointer

@gbpb_dont_write_seqptr:
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

; GBPB 8
gbpb8_rd_file_cur_dir:
        jsr     set_curdirdrv_to_defaults_check_cur_drv_cat
        lda     #<gbpb8_getbyte
        sta     fuji_param_block_lo
        lda     #>gbpb8_getbyte
        sta     fuji_param_block_hi
        bne     gbpb_rwdata                     ; always

gbpb8_getbyte:
        ldy     gbpb_seqptr                     ; GBPB 8 - Get Byte
@gbpb8_loop:
        cpy     dfs_cat_num_x8
        bcs     @gbpb8_endofcat                 ; If end of catalogue, C=1
        lda     dfs_cat_file_dir, y             ; Directory
        jsr     is_alpha_char
        eor     directory_param
        bcs     @gbpb8_notalpha
        and     #$DF
@gbpb8_notalpha:
        and     #$7F
        beq     @gbpb8_filefound                ; If in current dir
        jsr     y_add8
        bne     @gbpb8_loop                      ; next file
@gbpb8_filefound:
        lda     #$07                            ; Length of filename
        jsr     gbpb_gb_savebyte
        sta     aws_tmp00                       ; loop counter
@gbpb8_copyfn_loop:
        lda     dfs_cat_file_s0_start,Y         ; Copy fn
        jsr     gbpb_gb_savebyte
        iny
        dec     aws_tmp00
        bne     @gbpb8_copyfn_loop
        clc                                     ; C=0 indicates more to follow
@gbpb8_endofcat:
        sty     gbpb_seqptr                     ; Save offset (seq ptr)
        lda     dfs_cat_cycle
        sta     gbpb_file_handle                ; Cycle number (file handle)
        rts

;;
gbpb_gb_savebyte_and_gbpb_save_01:
        ora     #$30                            ; Drive no. to ascii
        jsr     gbpb_gb_savebyte
gbpb_save_01:
        lda     #$01
        bne     gbpb_gb_savebyte                ; always


gbpb_getbyte_savebyte:
        jsr     bgetv_entry
        bcs     gbpb_inc_dbl_word_exit          ; If EOF


gbpb_gb_savebyte:
        bit     gbpb_tube
        bpl     gbpb_gb_fromhost
        sta     TUBE_R3_DATA                    ; fast Tube Bget
        bmi     gbpb_inc_data_ptr
gbpb_gb_fromhost:
        jsr     gbpb_b8_memptr
        sta     (aws_tmp08, x)


gbpb_inc_data_ptr:
        jsr     remember_axy
        ldx     #$01

gbpb_inc_dbl_word_buf_x:
        ldy     #$04

@gbpb_inc_dbl_word_loop:
        inc     gbpb_buf_0c, x
        bne     gbpb_inc_dbl_word_exit
        inx
        dey
        bne     @gbpb_inc_dbl_word_loop

gbpb_inc_dbl_word_exit:
        rts

gbpb5_get_mediatitle:
        jsr     set_curdirdrv_to_defaults_check_cur_drv_cat
        lda     #$0C                            ; Length of title
        jsr     gbpb_gb_savebyte
        ldy     #$00
@gbpb5_titleloop:
        cpy     #$08                            ; Title
        bcs     @gbpb5_titlehi
        lda     dfs_cat_s0_title, y
        bcc     @gbpb5_titlelo
@gbpb5_titlehi:
        lda     dfs_cat_s1_title-8, y           ; adjust for the Y index of 8
@gbpb5_titlelo:
        jsr     gbpb_gb_savebyte
        iny
        cpy     #$0C
        bne     @gbpb5_titleloop
        lda     dfs_cat_boot_option
        jsr     a_rorx4
        jsr     gbpb_gb_savebyte
        lda     current_drv
        jmp     gbpb_gb_savebyte

gbpb6_rd_cur_dir_device:
        jsr     gbpb_save_01                      ; GBPB 6
        lda     fuji_default_drive                ; Length of dev.name=1
        jsr     gbpb_gb_savebyte_and_gbpb_save_01 ; Lendgh of dir.name=1
        lda     fuji_default_dir                  ; Directory
        bne     gbpb_gb_savebyte

gbpb7_rd_cur_lib_device:
        jsr     gbpb_save_01                      ; GBPB 7
        lda     fuji_lib_drive                    ; Length of dev.name=1
        jsr     gbpb_gb_savebyte_and_gbpb_save_01 ; Lendgh of dir.name=1
        lda     fuji_lib_dir                      ; Directory
        bne     gbpb_gb_savebyte

; set word aws_tmp08 to ctrl block mem pointer (host)
gbpb_b8_memptr:
        ldx     gbpb_ctl_blk_mem_ptr_host
        stx     aws_tmp08
        ldx     gbpb_ctl_blk_mem_ptr_host+1
        stx     aws_tmp09
        ldx     #$00
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
