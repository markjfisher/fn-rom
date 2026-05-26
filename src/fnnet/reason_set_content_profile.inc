fnnet_reason_set_content_profile:
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_network_content_profile
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit
