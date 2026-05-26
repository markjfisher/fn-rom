fnnet_fail:
        lda     #FNNET_STATUS_BAD_CALL
fnnet_exit:
        ldy     #$00
        sta     (aws_tmp14),y
        ldy     #$01
        sta     (aws_tmp14),y
        rts
