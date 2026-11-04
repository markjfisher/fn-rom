; Reason &08: local channel metadata, no bus access.
; +2 MOS handle, +3/4 firmware handle, +5/6 buffered bytes, +7 local ready.
fnnet_reason_channel_info:
        ldy #2
        lda (aws_tmp00),y
        tay
        jsr check_channel_yhndl_exyintch
        bcs @invalid
        tya
        tax
        lda fuji_ch_handle_low,x
        ora fuji_ch_handle_high,x
        beq @invalid
        ldy #3
        lda fuji_ch_handle_low,x
        sta (aws_tmp00),y
        iny
        lda fuji_ch_handle_high,x
        sta (aws_tmp00),y
        lda fuji_ch_bptr_low,x
        sec
        sbc fuji_ch_1118,x
        sta aws_tmp12
        lda fuji_ch_sect_cnt,x
        sec
        sbc aws_tmp12
        bcs :+
        lda #0
:       iny
        sta (aws_tmp00),y
        sta aws_tmp12
        lda #0
        iny
        sta (aws_tmp00),y
        lda aws_tmp12
        bne @ready
        lda fuji_ch_bptr_low,x
        cmp fuji_ch_ext_low,x
        bne @not_ready
        lda fuji_ch_bptr_mid,x
        cmp fuji_ch_ext_mid,x
        bne @not_ready
        lda fuji_ch_bptr_hi,x
        cmp fuji_ch_ext_hi,x
        bne @not_ready
@ready:
        lda #1
        bne @store
@not_ready:
        lda #0
@store:
        iny
        sta (aws_tmp00),y
        lda #FNNET_STATUS_OK
        jmp fnnet_exit
@invalid:
        jmp fnnet_fail
