; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling

        .include "fujinet.inc"

        .import calc_checksum
        .import restore_output_to_screen
        .import setup_serial_19200
        .import fujibus_read_slip_stream
        .import fujibus_write_slip_stream

        .import popa
        .import popax
        .import pusha
        .import pushax

        .segment "CODE"

        .export _fujibus_send_packet
        .export _fujibus_receive_packet

        ; for debug
        .export fujibus_send_packet_impl
        .export fujibus_receive_packet_impl

fujibus_header_size = 6

; void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)

_fujibus_send_packet:
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

        ldx     fuji_ax_save+1
        lda     fuji_ax_save
        jsr     fujibus_send_packet_impl

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


; Internal entry:
;   A/X     = paylen
;   stack   = payload (16), command (8), device (8)

fujibus_send_packet_impl:
        ; save paylen
        sta     aws_tmp02
        stx     aws_tmp03

        ; payload pointer
        jsr     popax
        sta     aws_tmp00
        stx     aws_tmp01

        ; command -> tx buffer[1]
        jsr     popa
        ldy     #$01
        sta     (buffer_ptr),y

        ; device -> tx buffer[0]
        jsr     popa
        ldy     #$00
        sta     (buffer_ptr),y

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
        ldy     #$04
        sta     (buffer_ptr),y

        ; restore total_len, since calc_checksum consumed it
        lda     fuji_ax_save
        sta     aws_tmp02
        lda     fuji_ax_save+1
        sta     aws_tmp03

        ; stream packet as SLIP directly to serial
        lda     buffer_ptr
        sta     aws_tmp00
        lda     buffer_ptr+1
        sta     aws_tmp01
        ; aws_tmp02/03 still = total_len
        jsr     fujibus_write_slip_stream
        rts

; uint16_t fujibus_receive_packet(void)

_fujibus_receive_packet:
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
        jsr     fujibus_read_slip_stream

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
