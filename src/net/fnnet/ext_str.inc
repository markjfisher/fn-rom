fnnet_load_ext_str:
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_ext_str_ptr
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_ptr+1
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_len
        iny
        lda     (aws_tmp00),y
        sta     fuji_ext_str_len_hi

        lda     fuji_ext_str_len
        ora     fuji_ext_str_len_hi
        beq     fnnet_load_fail

        lda     fuji_ext_str_len_hi
        cmp     #>(FUJI_EXT_STR_MAX_LEN + 1)
        bcc     fnnet_load_ok
        bne     fnnet_load_fail
        lda     fuji_ext_str_len
        cmp     #<FUJI_EXT_STR_MAX_LEN + 1
        bcs     fnnet_load_fail
fnnet_load_ok:
        lda     #$00
        sta     fuji_ext_str_flags
        clc
        rts
fnnet_load_fail:
        jsr     fnnet_clear_ext_state
        sec
        rts

; A = flags to ORA into fuji_ext_str_flags
fnnet_set_flags_and_len:
        ora     fuji_ext_str_flags
        sta     fuji_ext_str_flags
        lda     fuji_ext_str_len
        sta     fuji_json_path_len
        rts

fnnet_clear_ext_state:
        lda     #$00
        sta     fuji_ext_str_flags
        sta     fuji_ext_str_len
        sta     fuji_ext_str_len_hi
        sta     fuji_ext_str_ptr
        sta     fuji_ext_str_ptr+1
        sta     fuji_json_path_len
        rts

; Entry: Y = intch, A = $00
fnnet_clear_channel_read_state_y:
        sta     fuji_ch_ext_low,y
        sta     fuji_ch_ext_mid,y
        sta     fuji_ch_ext_hi,y
        sta     fuji_ch_bptr_low,y
        sta     fuji_ch_bptr_mid,y
        sta     fuji_ch_bptr_hi,y
        sta     fuji_ch_sect_cnt,y
        rts
