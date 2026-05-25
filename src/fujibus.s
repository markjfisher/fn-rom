; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling

        .include "fujinet.inc"

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp02
        .importzp aws_tmp03
        .importzp aws_tmp04
        .importzp aws_tmp05
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp10
        .importzp aws_tmp11
        .importzp aws_tmp14
        .importzp aws_tmp15
        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp cws_tmp6
        .importzp cws_tmp7

        .importzp buffer_ptr
        .importzp fuji_bus_tx_command
        .importzp fuji_bus_tx_device
        .importzp fuji_bus_tx_payload_hi
        .importzp fuji_bus_tx_payload_lo

        .import calc_checksum
        .import calc_checksum_continue
        .import fuji_ax_save
        .import fuji_link_read_slip_frame
        .import fuji_link_write_slip_frame
        .import fuji_link_write_slip_frame_triple

        .segment "CODE"

        .export fujibus_send_packet
        .export fujibus_send_packet_scatter
        .export fujibus_receive_packet

        ; for debug
        .export fujibus_send_packet_impl
        .export fujibus_receive_packet_impl
        .export scatter_after_checksum
        .export scatter_after_checksum_r2
        .export scatter_after_checksum_r3
        .export scatter_store_checksum
        .export scatter_before_write

fujibus_header_size = 6

; void fujibus_send_packet(uint16_t paylen);  A/X = payload byte count
;
; Caller must set ZP slots (see os.s): fuji_bus_tx_device, fuji_bus_tx_command,
; fuji_bus_tx_payload_lo/hi → first byte of payload source to copy after the wire header.

fujibus_send_packet:
        sta     fuji_ax_save
        stx     fuji_ax_save+1

        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha
        lda     aws_tmp02
        pha
        lda     aws_tmp03
        pha
        lda     aws_tmp08
        pha
        lda     aws_tmp09
        pha

        lda     fuji_ax_save
        sta     aws_tmp02
        lda     fuji_ax_save+1
        sta     aws_tmp03

        lda     fuji_bus_tx_payload_lo
        sta     aws_tmp00
        lda     fuji_bus_tx_payload_hi
        sta     aws_tmp01

        ldy     #$00
        lda     fuji_bus_tx_device
        sta     (buffer_ptr),y
        iny
        lda     fuji_bus_tx_command
        sta     (buffer_ptr),y

        ; fall through to impl
        ; jmp     fujibus_send_packet_impl


; Internal: aws_tmp02/03 = paylen, aws_tmp00/01 = payload ptr, buffer [0],[1] = dev/cmd

fujibus_send_packet_impl:
        ; destination pointer = buffer + header size
        lda     buffer_ptr
        clc
        adc     #fujibus_header_size
        sta     aws_tmp08
        lda     buffer_ptr+1
        adc     #$00
        sta     aws_tmp09

        ldy     #$00

@copy_payload:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @payload_done

        lda     (aws_tmp00),y
        sta     (aws_tmp08),y

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02
        jmp     @copy_payload

@payload_done:
        ; total_len = current dest ptr - buffer base
        lda     aws_tmp08
        sec
        sbc     buffer_ptr
        sta     aws_tmp02
        ldy     #$02
        sta     (buffer_ptr),y

        lda     aws_tmp09
        sbc     buffer_ptr+1
        sta     aws_tmp03
        iny                             ; Y = 3
        sta     (buffer_ptr),y

        ; checksum placeholder + descriptor
        lda     #$00
        iny                             ; Y = 4
        sta     (buffer_ptr),y
        iny                             ; Y = 5
        sta     (buffer_ptr),y

        ; save total_len across calc_checksum
        lda     aws_tmp02
        sta     fuji_ax_save
        lda     aws_tmp03
        sta     fuji_ax_save+1

        ; checksum over full packet
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        ; aws_tmp02/03 = total_len for checksum input
        jsr     calc_checksum
scatter_after_checksum:
        ldy     #$04
        sta     (buffer_ptr),y

        ; restore total_len, since calc_checksum consumed it
        lda     fuji_ax_save
        sta     aws_tmp02
        lda     fuji_ax_save+1
        sta     aws_tmp03

        ; stream packet as SLIP over the selected channel
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        ; aws_tmp02/03 still = total_len
        jsr     fuji_link_write_slip_frame

        pla
        sta     aws_tmp09
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp03
        pla
        sta     aws_tmp02
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00
        rts


; void fujibus_send_packet_scatter(void)
; Region 1: aws_tmp00/01 ptr, aws_tmp02/03 len (includes FujiBus header)
; Region 2: aws_tmp06/07 ptr, aws_tmp08/09 len (optional)
; Region 3: cws_tmp2/3 ptr, cws_tmp6/7 len (optional)

fujibus_send_packet_scatter:
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha
        lda     aws_tmp02
        pha
        lda     aws_tmp03
        pha
        lda     aws_tmp08
        pha
        lda     aws_tmp09
        pha
        lda     aws_tmp06
        pha
        lda     aws_tmp07
        pha
        lda     cws_tmp2
        pha
        lda     cws_tmp3
        pha
        lda     cws_tmp6
        pha
        lda     cws_tmp7
        pha

        ldy     #$00
        lda     fuji_bus_tx_device
        sta     (buffer_ptr),y
        iny
        lda     fuji_bus_tx_command
        sta     (buffer_ptr),y

        lda     aws_tmp02
        sta     fuji_ax_save
        lda     aws_tmp03
        sta     fuji_ax_save+1
        lda     aws_tmp08
        clc
        adc     fuji_ax_save
        sta     fuji_ax_save
        lda     aws_tmp09
        adc     fuji_ax_save+1
        sta     fuji_ax_save+1
        lda     cws_tmp6
        clc
        adc     fuji_ax_save
        sta     fuji_ax_save
        lda     cws_tmp7
        adc     fuji_ax_save+1
        sta     fuji_ax_save+1

        ldy     #$02
        lda     fuji_ax_save
        sta     (buffer_ptr),y
        iny
        lda     fuji_ax_save+1
        sta     (buffer_ptr),y
        iny
        lda     #$00
        sta     (buffer_ptr),y
        iny
        sta     (buffer_ptr),y

        jsr     calc_checksum

        lda     aws_tmp08
        ora     aws_tmp09
        beq     scatter_after_checksum_r2
        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03
        jsr     calc_checksum_continue
scatter_after_checksum_r2:

        lda     cws_tmp6
        ora     cws_tmp7
        beq     scatter_after_checksum_r3
        lda     cws_tmp2
        sta     aws_tmp00
        lda     cws_tmp3
        sta     aws_tmp01
        lda     cws_tmp6
        sta     aws_tmp02
        lda     cws_tmp7
        sta     aws_tmp03
        jsr     calc_checksum_continue
scatter_after_checksum_r3:

scatter_store_checksum:
        ldy     #$04
        lda     aws_tmp04               ; checksum result from calc_checksum(_continue)
        sta     (buffer_ptr),y

        pla
        sta     cws_tmp7
        pla
        sta     cws_tmp6
        pla
        sta     cws_tmp3
        pla
        sta     cws_tmp2
        pla
        sta     aws_tmp07
        pla
        sta     aws_tmp06
        pla
        sta     aws_tmp09
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp03
        pla
        sta     aws_tmp02
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00

scatter_before_write:
        jsr     fuji_link_write_slip_frame_triple
        rts


; uint16_t fujibus_receive_packet(void)

fujibus_receive_packet:
        lda     aws_tmp00
        pha
        lda     aws_tmp01
        pha
        lda     aws_tmp02
        pha
        lda     aws_tmp03
        pha
        lda     aws_tmp04
        pha
        lda     aws_tmp05
        pha
        lda     aws_tmp08
        pha
        lda     aws_tmp09
        pha
        lda     aws_tmp10
        pha
        lda     aws_tmp11
        pha

        jsr     fujibus_receive_packet_impl

        sta     fuji_ax_save
        stx     fuji_ax_save+1

        pla
        sta     aws_tmp11
        pla
        sta     aws_tmp10
        pla
        sta     aws_tmp09
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp05
        pla
        sta     aws_tmp04
        pla
        sta     aws_tmp03
        pla
        sta     aws_tmp02
        pla
        sta     aws_tmp01
        pla
        sta     aws_tmp00

        ldx     fuji_ax_save+1
        lda     fuji_ax_save
        rts


fujibus_receive_packet_impl:
        ; receive and decode SLIP into buffer at buffer_ptr
        jsr     fuji_link_read_slip_frame

        ; dec_len -> aws_tmp02/03
        sta     aws_tmp02
        stx     aws_tmp03

        ; if dec_len == 0 return 0
        cpx     #$00
        bne     @check_min
        cmp     #$00
        beq     @fail

        ; if dec_len < fujibus_header_size return 0
        ; (fujibus_header_size = 6)
@check_min:
        lda     aws_tmp03
        bne     @validate_checksum
        lda     aws_tmp02
        cmp     #fujibus_header_size
        bcs     @validate_checksum
        jmp     @fail

@validate_checksum:
        ; chk_received = rx[4] — must not use aws_tmp04; calc_checksum clobbers it.
        ldy     #$04
        lda     (buffer_ptr),y
        sta     aws_tmp05

        ; rx[4] = 0
        lda     #$00
        sta     (buffer_ptr),y

        ; preserve dec_len across calc_checksum
        lda     aws_tmp02
        sta     aws_tmp10
        lda     aws_tmp03
        sta     aws_tmp11

        ; calc_checksum(buffer_ptr, dec_len) → A = computed checksum
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        lda     aws_tmp10
        sta     aws_tmp02
        lda     aws_tmp11
        sta     aws_tmp03
        jsr     calc_checksum

        cmp     aws_tmp05
        beq     :+

        ; checksum mismatch — restore wire byte for debugging, then fail
        ldy     #$04
        lda     aws_tmp05
        sta     (buffer_ptr),y
        jmp     @fail

:
        ; restore original checksum byte
        ldy     #$04
        lda     aws_tmp05
        sta     (buffer_ptr),y

        lda     aws_tmp10
        ldx     aws_tmp11
        rts

@fail:
        lda     #$00
        tax
        rts
