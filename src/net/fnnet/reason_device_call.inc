; Reason &06 — raw FujiBus device call into caller request/response buffers.
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

        ; Receive the 7-byte FujiBus response header into ROM workspace and
        ; stream response payload bytes directly into the caller's buffer.
        ldy     #$09
        lda     (aws_tmp14),y
        sta     aws_tmp06
        iny
        lda     (aws_tmp14),y
        sta     aws_tmp07
        iny
        lda     (aws_tmp14),y
        sta     aws_tmp08
        iny
        lda     (aws_tmp14),y
        sta     aws_tmp09
        jsr     fujibus_receive_packet_to_payload

        ; total response length in A/X
        sta     aws_tmp02
        stx     aws_tmp03
        txa
        bne     @len_ok
        lda     aws_tmp02
        cmp     #$07
        bcc     @bad_call

@len_ok:
        lda     aws_tmp12
        cmp     #$01
        bne     @bad_call

        ; device status out
        lda     aws_tmp13
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

        ; Fail if caller response buffer was too small. The streamed receive
        ; already drained the frame, so the link remains synchronized.
        ldy     #$0B
        lda     (aws_tmp14),y
        sec
        sbc     aws_tmp08
        iny
        lda     (aws_tmp14),y
        sbc     aws_tmp09
        bcc     @bad_call

@ok:
        lda     #FNNET_STATUS_OK
        jmp     fnnet_exit

@bad_call:
        lda     #FNNET_STATUS_BAD_CALL
        jmp     fnnet_exit
