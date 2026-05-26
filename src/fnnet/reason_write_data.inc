fnnet_reason_write_data:
        jsr     fnnet_load_ext_str
        bcs     fnnet_fail

        ldy     #$06
        lda     (aws_tmp00),y
        tay
        jsr     check_channel_yhndl_exyintch
        bcs     fnnet_write_failed

        sty     aws_tmp02

        jsr     network_flush_write
        bcs     fnnet_write_failed

        ldy     aws_tmp02
        lda     fuji_ch_write_count,y
        beq     :+
        lda     #$00
        sta     fuji_ch_write_count,y
:

        lda     fuji_ch_write_pos_low,y
        sta     aws_tmp06
        lda     fuji_ch_write_pos_mid,y
        sta     aws_tmp07
        lda     fuji_ch_write_pos_hi,y
        sta     aws_tmp08
        lda     #$00
        sta     aws_tmp09

        jsr     fujibus_network_write_ext
        bcs     fnnet_write_failed

        ; advance write position by bulk payload length
        ldy     aws_tmp02
        lda     fuji_ch_write_pos_low,y
        clc
        adc     fuji_ext_str_len
        sta     fuji_ch_write_pos_low,y
        lda     fuji_ch_write_pos_mid,y
        adc     fuji_ext_str_len_hi
        sta     fuji_ch_write_pos_mid,y
        lda     fuji_ch_write_pos_hi,y
        adc     #$00
        sta     fuji_ch_write_pos_hi,y

        lda     #FNNET_STATUS_OK
        beq     fnnet_exit

fnnet_write_failed:
        jsr     fnnet_clear_ext_state
        lda     #FNNET_STATUS_BAD_CALL
        bne     fnnet_exit
