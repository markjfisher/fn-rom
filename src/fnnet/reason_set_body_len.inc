fnnet_reason_set_body_len:
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_network_body_len
        iny
        lda     (aws_tmp00),y
        sta     fuji_network_body_len_hi
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit
