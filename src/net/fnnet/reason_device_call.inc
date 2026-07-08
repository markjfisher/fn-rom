; Reason &06 — raw FujiBus device call for small request/response payloads.
;
; Block layout:
;   +2  device id in
;   +3  device command in
;   +4  device status out
;   +5  request pointer lo
;   +6  request pointer hi
;   +7  request length lo
;   +8  request length hi
;   +9  response pointer lo
;   +10 response pointer hi
;   +11 response capacity lo
;   +12 response capacity hi
;   +13 response payload length lo out
;   +14 response payload length hi out

fnnet_reason_device_call:
        ; device
        ldy     #$02
        lda     (aws_tmp00),y
        sta     fuji_bus_tx_device

        ; command
        iny
        lda     (aws_tmp00),y
        sta     fuji_bus_tx_command

        ; skip device status out
        iny

        ; request pointer -> region 2 pointer
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp06
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp07

        ; request length -> region 2 length
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp08
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp09

        ; skip response pointer for now; it is reloaded after receive.
        iny
        iny

        ; response capacity -> aws_tmp10/11
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp10
        iny
        lda     (aws_tmp00),y
        sta     aws_tmp11

        ; Region 1 is the FujiBus header only. Region 2 is caller request.
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     #FN_HEADER_SIZE
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03

        ; no region 3
        sta     cws_tmp6
        sta     cws_tmp7

        jsr     fujibus_send_packet_scatter
        jsr     fujibus_receive_packet

        ; total response length in A/X
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        bne     @len_ok
        lda     aws_tmp02
        cmp     #$07
        bcc     @bad_call

@len_ok:
        ldy     #$05
        lda     (buffer_ptr),y
        cmp     #$01
        bne     @bad_call

        ; device status out
        iny
        lda     (buffer_ptr),y
        ldy     #$04
        sta     (aws_tmp14),y

        ; payload length = total length - 7
        lda     aws_tmp02
        sec
        sbc     #$07
        sta     aws_tmp08
        lda     aws_tmp03
        sbc     #$00
        sta     aws_tmp09

        ; write actual response payload length to block +13/+14
        ldy     #$0D
        lda     aws_tmp08
        sta     (aws_tmp14),y
        iny
        lda     aws_tmp09
        sta     (aws_tmp14),y

        ; Fail if caller response buffer is too small.
        lda     aws_tmp10
        sec
        sbc     aws_tmp08
        lda     aws_tmp11
        sbc     aws_tmp09
        bcc     @bad_call

@copy_setup:
        lda     aws_tmp08
        ora     aws_tmp09
        beq     @ok

        ; Reload destination response pointer from the parameter block.
        ldy     #$09
        lda     (aws_tmp14),y
        sta     cws_tmp6
        iny
        lda     (aws_tmp14),y
        sta     cws_tmp7

        ; source = buffer + 7
        lda     buffer_ptr
        clc
        adc     #$07
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        ; destination pointer is in cws_tmp6/7. Count in aws_tmp08/09.
        ldy     #$00
@copy_loop:
        lda     aws_tmp08
        ora     aws_tmp09
        beq     @ok

        lda     (cws_tmp2),y
        sta     (cws_tmp6),y

        inc     cws_tmp2
        bne     :+
        inc     cws_tmp3
:
        inc     cws_tmp6
        bne     :+
        inc     cws_tmp7
:
        lda     aws_tmp08
        bne     :+
        dec     aws_tmp09
:
        dec     aws_tmp08
        jmp     @copy_loop

@ok:
        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit

@bad_call:
        lda     #FNNET_STATUS_BAD_CALL
        jmp     fnnet_exit
