; Reason &07: read one buffered network chunk into caller RAM.
; +2/3 destination, +4 capacity 1..255, +6 MOS handle,
; +7 flags out (1 EOF, 2 NotReady), +8 actual count, +10 private slot.
; Existing BGET owns refills, EOF and no-probe boundaries; copy remaining
; buffered bytes directly, without repeatedly entering MOS for every byte.
fnnet_reason_read_data:
        ldy #8
        lda #0
        sta (aws_tmp00),y
        dey
        sta (aws_tmp00),y
        ldy #4
        lda (aws_tmp00),y
        beq @invalid
        sta aws_tmp12
        ldy #2
        lda (aws_tmp00),y
        clc
        adc aws_tmp12
        iny
        lda (aws_tmp00),y
        adc #0
        bcs @invalid
        ldy #6
        lda (aws_tmp00),y
        tay
        jsr check_channel_yhndl_exyintch
        bcs @invalid
        lda fuji_ch_handle_low,y
        ora fuji_ch_handle_high,y
        beq @invalid
        tya
        ldy #10
        sta (aws_tmp00),y
        lda aws_tmp15
        pha
        lda aws_tmp14
        pha
        ldy #6
        lda (aws_tmp00),y
        tay
        jsr bgetv_entry
        sta aws_tmp12
        php
        pla
        sta aws_tmp13
        pla
        sta aws_tmp14
        pla
        sta aws_tmp15
        lda aws_tmp13
        lsr a
        bcc @data
        lda #1
        ldx aws_tmp12
        cpx #$FE
        bne :+
        lda #2
:       ldy #7
        sta (aws_tmp14),y
        jmp @ok
@invalid:
        jmp fnnet_fail
@data:
        ldy #2
        lda (aws_tmp14),y
        sta aws_tmp06
        iny
        lda (aws_tmp14),y
        sta aws_tmp07
        ldy #0
        lda aws_tmp12
        sta (aws_tmp06),y
        ldy #10
        lda (aws_tmp14),y
        tax
        lda fuji_ch_bptr_low,x
        sec
        sbc fuji_ch_1118,x
        sta aws_tmp10
        lda fuji_ch_buf_page,x
        sta aws_tmp11
        lda fuji_ch_sect_cnt,x
        sec
        sbc aws_tmp10
        sta aws_tmp12             ; remaining bytes in current buffer
        ldy #4
        lda (aws_tmp14),y
        sec
        sbc #1
        cmp aws_tmp12
        bcs :+
        sta aws_tmp12
:       inc aws_tmp06
        bne :+
        inc aws_tmp07
:       ldy #0
@copy:
        cpy aws_tmp12
        beq @copied
        lda (aws_tmp10),y
        sta (aws_tmp06),y
        iny
        bne @copy
@copied:
        tya
        clc
        adc fuji_ch_bptr_low,x
        sta fuji_ch_bptr_low,x
        bcc :+
        inc fuji_ch_bptr_mid,x
        bne :+
        inc fuji_ch_bptr_hi,x
:       iny
        tya
        ldy #8
        sta (aws_tmp14),y
@ok:
        lda #FNNET_STATUS_OK
        jmp fnnet_exit
