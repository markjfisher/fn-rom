; FujiBus Protocol Implementation for BBC Micro
; Implements SLIP framing and FujiBus packet handling

        .include "fujinet.inc"

        .import _read_serial_data
        .import _write_serial_data
        .import calc_checksum
        .import restore_output_to_screen
        .import setup_serial_19200
        .import popa
        .import popax
        .import pusha
        .import pushax

        .segment "CODE"

        .export _fujibus_slip_encode
        .export _fujibus_slip_decode
        .export _fujibus_send_packet
        .export _fujibus_receive_packet

fujibus_header_size = 6

; _fujibus_slip_encode
;   Input:
;     aws_tmp00/01 = source pointer
;     aws_tmp02/03 = source length
;   Output:
;     _fuji_rx_buffer = SLIP-encoded frame
;     A/X = encoded length (16-bit)
;   Uses:
;     aws_tmp04 = current input byte
;     aws_tmp08/09 = encoded output pointer

_fujibus_slip_encode:
        lda     aws_tmp04
        pha
        lda     aws_tmp08
        pha
        lda     aws_tmp09
        pha

        jsr     fujibus_slip_encode_impl

        sta     fuji_ax_save
        stx     fuji_ax_save+1

        pla
        sta     aws_tmp09
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp04

        ldx     fuji_ax_save+1
        lda     fuji_ax_save
        rts


fujibus_slip_encode_impl:
        lda     #<_fuji_rx_buffer
        sta     aws_tmp08
        lda     #>_fuji_rx_buffer
        sta     aws_tmp09

        ldy     #$00
        lda     #SLIP_END
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:

@encode_loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @encode_done

        lda     (aws_tmp00),y
        sta     aws_tmp04

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02

        lda     aws_tmp04
        cmp     #SLIP_END
        beq     @escape_end
        cmp     #SLIP_ESCAPE
        beq     @escape_escape

        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @encode_loop
        inc     aws_tmp09
        jmp     @encode_loop

@escape_end:
        lda     #SLIP_ESCAPE
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        lda     #SLIP_ESC_END
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @encode_loop
        inc     aws_tmp09
        jmp     @encode_loop

@escape_escape:
        lda     #SLIP_ESCAPE
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        lda     #SLIP_ESC_ESC
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @encode_loop
        inc     aws_tmp09
        jmp     @encode_loop

@encode_done:
        lda     #SLIP_END
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     :+
        inc     aws_tmp09
:
        lda     aws_tmp08
        sec
        sbc     #<_fuji_rx_buffer
        pha

        lda     aws_tmp09
        sbc     #>_fuji_rx_buffer
        tax

        pla
        rts

; _fujibus_slip_decode
;   Input:
;     aws_tmp00/01 = pointer to SLIP-encoded buffer
;     aws_tmp02/03 = encoded length
;   Output:
;     _fuji_rx_buffer = decoded packet
;     A/X = decoded length, or 0 on error
;   Uses:
;     aws_tmp04/05 = scratch
;     aws_tmp08/09 = decoded output pointer

_fujibus_slip_decode:
        lda     aws_tmp04
        pha
        lda     aws_tmp05
        pha
        lda     aws_tmp08
        pha
        lda     aws_tmp09
        pha

        jsr     fujibus_slip_decode_impl

        sta     fuji_ax_save
        stx     fuji_ax_save+1

        pla
        sta     aws_tmp09
        pla
        sta     aws_tmp08
        pla
        sta     aws_tmp05
        pla
        sta     aws_tmp04

        ldx     fuji_ax_save+1
        lda     fuji_ax_save
        rts


fujibus_slip_decode_impl:
        lda     aws_tmp03
        bne     @check_markers
        lda     aws_tmp02
        cmp     #$02
        bcs     @check_markers
        lda     #$00
        tax
        rts

@check_markers:
        ldy     #$00

        lda     (aws_tmp00),y
        cmp     #SLIP_END
        beq     :+
        lda     #$00
        tax
        rts
:
        lda     aws_tmp00
        clc
        adc     aws_tmp02
        sta     aws_tmp04
        lda     aws_tmp01
        adc     aws_tmp03
        sta     aws_tmp05

        lda     aws_tmp04
        sec
        sbc     #$01
        sta     aws_tmp04
        lda     aws_tmp05
        sbc     #$00
        sta     aws_tmp05

        lda     (aws_tmp04),y
        cmp     #SLIP_END
        beq     :+
        lda     #$00
        tax
        rts
:
        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        sec
        sbc     #$02
        sta     aws_tmp02
        lda     aws_tmp03
        sbc     #$00
        sta     aws_tmp03

        lda     #<_fuji_rx_buffer
        sta     aws_tmp08
        lda     #>_fuji_rx_buffer
        sta     aws_tmp09

@decode_loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @decode_done

        lda     (aws_tmp00),y
        sta     aws_tmp04

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02

        lda     aws_tmp04
        cmp     #SLIP_ESCAPE
        beq     @handle_escape
        cmp     #SLIP_END
        bne     :+
        lda     #$00                  ; unexpected END inside frame
        tax
        rts
:
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @decode_loop
        inc     aws_tmp09
        jmp     @decode_loop

@handle_escape:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @decode_error         ; ESC cannot be final interior byte

        lda     (aws_tmp00),y
        sta     aws_tmp04

        inc     aws_tmp00
        bne     :+
        inc     aws_tmp01
:
        lda     aws_tmp02
        bne     :+
        dec     aws_tmp03
:
        dec     aws_tmp02

        lda     aws_tmp04
        cmp     #SLIP_ESC_END
        beq     :+
        cmp     #SLIP_ESC_ESC
        beq     :++
        jmp     @decode_error         ; invalid escape sequence
:
        lda     #SLIP_END
        jmp     @store_decoded
:
        lda     #SLIP_ESCAPE

@store_decoded:
        sta     (aws_tmp08),y
        inc     aws_tmp08
        bne     @decode_loop
        inc     aws_tmp09
        jmp     @decode_loop

@decode_done:
        lda     aws_tmp08
        sec
        sbc     #<_fuji_rx_buffer
        pha

        lda     aws_tmp09
        sbc     #>_fuji_rx_buffer
        tax

        pla
        rts

@decode_error:
        lda     #$00
        tax
        rts

; ; uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)
; _fujibus_build_packet:
;         sta     aws_tmp02
;         stx     aws_tmp03
;         jsr     popax
;         sta     aws_tmp00         ; payload ptr lo
;         stx     aws_tmp01         ; payload ptr hi
;         jsr     popa
;         sta     aws_tmp05         ; command
;         jsr     popa
;         sta     aws_tmp04         ; device

;         lda     aws_tmp02
;         clc
;         adc     #fujibus_header_size
;         sta     aws_tmp06
;         lda     aws_tmp03
;         adc     #$00
;         sta     aws_tmp07

;         lda     aws_tmp04
;         sta     _fuji_tx_buffer+0
;         lda     aws_tmp05
;         sta     _fuji_tx_buffer+1
;         lda     aws_tmp06
;         sta     _fuji_tx_buffer+2
;         lda     aws_tmp07
;         sta     _fuji_tx_buffer+3
;         lda     #$00
;         sta     _fuji_tx_buffer+4
;         sta     _fuji_tx_buffer+5

;         lda     #<(_fuji_tx_buffer + fujibus_header_size)
;         sta     aws_tmp08
;         lda     #>(_fuji_tx_buffer + fujibus_header_size)
;         sta     aws_tmp09

;         ldy     #$00
; @copy_payload:
;         lda     aws_tmp02
;         ora     aws_tmp03
;         beq     @checksum

;         lda     (aws_tmp00),y
;         sta     (aws_tmp08),y

;         inc     aws_tmp00
;         bne     :+
;         inc     aws_tmp01
; :
;         inc     aws_tmp08
;         bne     :+
;         inc     aws_tmp09
; :
;         lda     aws_tmp02
;         bne     :+
;         dec     aws_tmp03
; :
;         dec     aws_tmp02
;         jmp     @copy_payload

; @checksum:
;         lda     #<_fuji_tx_buffer
;         sta     aws_tmp00
;         lda     #>_fuji_tx_buffer
;         sta     aws_tmp01
;         lda     aws_tmp06
;         sta     aws_tmp02
;         lda     aws_tmp07
;         sta     aws_tmp03
;         jsr     calc_checksum
;         sta     _fuji_tx_buffer+4
;         lda     aws_tmp06
;         ldx     aws_tmp07
;         rts

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
        lda     aws_tmp04
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
        sta     aws_tmp04
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
        sta     _fuji_tx_buffer+1

        ; device -> tx buffer[0]
        jsr     popa
        sta     _fuji_tx_buffer+0

        ; header placeholders
        lda     #$00
        sta     _fuji_tx_buffer+4      ; checksum
        sta     _fuji_tx_buffer+5      ; descriptor

        ; destination pointer = tx buffer + header size
        lda     #<(_fuji_tx_buffer + fujibus_header_size)
        sta     aws_tmp08
        lda     #>(_fuji_tx_buffer + fujibus_header_size)
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
        ; total_len = current dest ptr - _fuji_tx_buffer
        lda     aws_tmp08
        sec
        sbc     #<_fuji_tx_buffer
        sta     aws_tmp02
        sta     _fuji_tx_buffer+2      ; length low

        lda     aws_tmp09
        sbc     #>_fuji_tx_buffer
        sta     aws_tmp03
        sta     _fuji_tx_buffer+3      ; length high

        ; checksum over tx buffer
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        jsr     calc_checksum
        sta     _fuji_tx_buffer+4

        ; SLIP encode tx buffer -> rx buffer
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        ; aws_tmp02/03 already = total_len
        jsr     fujibus_slip_encode_impl

        ; write_serial_data expects:
        ;   aws_tmp00/01 = buffer pointer
        ;   aws_tmp02/03 = length
        sta     aws_tmp02
        stx     aws_tmp03

        jsr     setup_serial_19200

        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01

        jsr     _write_serial_data
        jsr     restore_output_to_screen
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
        jsr     setup_serial_19200

        ; read_serial_data(_fuji_rx_buffer, $01FF, &aws_tmp10)
        lda     #<_fuji_rx_buffer
        ldx     #>_fuji_rx_buffer
        jsr     pushax

        lda     #$FF
        ldx     #$01
        jsr     pushax

        lda     #<aws_tmp10
        ldx     #>aws_tmp10
        jsr     _read_serial_data

        jsr     restore_output_to_screen

        ; if (slip_len == 0) return 0
        lda     aws_tmp10
        ora     aws_tmp11
        bne     :+
        lda     #$00
        tax
        rts
:
        ; dec_len = fujibus_slip_decode(_fuji_rx_buffer, slip_len)
        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01
        lda     aws_tmp10
        sta     aws_tmp02
        lda     aws_tmp11
        sta     aws_tmp03
        jsr     fujibus_slip_decode_impl

        sta     aws_tmp02              ; dec_len lo
        stx     aws_tmp03              ; dec_len hi

        ; if (dec_len < fujibus_header_size) return 0
        lda     aws_tmp03
        bne     @validate_checksum
        lda     aws_tmp02
        cmp     #fujibus_header_size
        bcs     @validate_checksum
        lda     #$00
        tax
        rts

@validate_checksum:
        ; chk_received = _fuji_rx_buffer[4]
        lda     _fuji_rx_buffer+4
        sta     aws_tmp04

        ; _fuji_rx_buffer[4] = 0
        lda     #$00
        sta     _fuji_rx_buffer+4

        ; preserve dec_len across calc_checksum
        lda     aws_tmp02
        sta     aws_tmp10
        lda     aws_tmp03
        sta     aws_tmp11

        ; chk_computed = calc_checksum(_fuji_rx_buffer, dec_len)
        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01
        lda     aws_tmp10
        sta     aws_tmp02
        lda     aws_tmp11
        sta     aws_tmp03
        jsr     calc_checksum

        ; compare and restore original checksum byte
        cmp     aws_tmp04
        beq     :+

        lda     aws_tmp04
        sta     _fuji_rx_buffer+4
        lda     #$00
        tax
        rts

:
        lda     aws_tmp04
        sta     _fuji_rx_buffer+4
        lda     aws_tmp10
        ldx     aws_tmp11
        rts