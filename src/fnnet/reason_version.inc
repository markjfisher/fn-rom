fnnet_reason_version:
        ldy     #$08
        lda     #<fnnet_call_entry
        sta     (aws_tmp00),y
        iny
        lda     #>fnnet_call_entry
        sta     (aws_tmp00),y
        lda     #FNNET_STATUS_OK
        beq     fnnet_exit
