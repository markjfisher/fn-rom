fnnet_reason_set_open_flags:
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_network_open_flags
        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit
