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
        .export _fujibus_build_packet
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

; uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)
_fujibus_build_packet:
        sta     aws_tmp02
        stx     aws_tmp03
        jsr     popax
        sta     aws_tmp00         ; payload ptr lo
        stx     aws_tmp01         ; payload ptr hi
        jsr     popa
        sta     aws_tmp05         ; command
        jsr     popa
        sta     aws_tmp04         ; device

        lda     aws_tmp02
        clc
        adc     #fujibus_header_size
        sta     aws_tmp06
        lda     aws_tmp03
        adc     #$00
        sta     aws_tmp07

        lda     aws_tmp04
        sta     _fuji_tx_buffer+0
        lda     aws_tmp05
        sta     _fuji_tx_buffer+1
        lda     aws_tmp06
        sta     _fuji_tx_buffer+2
        lda     aws_tmp07
        sta     _fuji_tx_buffer+3
        lda     #$00
        sta     _fuji_tx_buffer+4
        sta     _fuji_tx_buffer+5

        lda     #<(_fuji_tx_buffer + fujibus_header_size)
        sta     aws_tmp08
        lda     #>(_fuji_tx_buffer + fujibus_header_size)
        sta     aws_tmp09

        ldy     #$00
@copy_payload:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @checksum

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

@checksum:
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        lda     aws_tmp06
        sta     aws_tmp02
        lda     aws_tmp07
        sta     aws_tmp03
        jsr     calc_checksum
        sta     _fuji_tx_buffer+4
        lda     aws_tmp06
        ldx     aws_tmp07
        rts

; void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)
; void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)

_fujibus_send_packet:
        ; On entry from C:
        ;   A/X     = paylen
        ;   stack   = payload (16), command (8), device (8)

        sta     aws_tmp02              ; paylen lo
        stx     aws_tmp03              ; paylen hi

        jsr     popax
        sta     aws_tmp00              ; payload ptr lo
        stx     aws_tmp01              ; payload ptr hi

        jsr     popa
        sta     aws_tmp05              ; command

        jsr     popa
        sta     aws_tmp04              ; device

        ; Build packet:
        ;   fujibus_build_packet(device, command, payload, paylen)
        ;
        ; For C call:
        ;   push all but last parameter right-to-left
        ;   final parameter goes in A/X
        ;
        ; Signature:
        ;   (uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen)
        ;
        ; So:
        ;   push paylen
        ;   push payload
        ;   push command
        ;   A = device

        lda     aws_tmp02
        ldx     aws_tmp03
        jsr     pushax                 ; push paylen

        lda     aws_tmp00
        ldx     aws_tmp01
        jsr     pushax                 ; push payload

        lda     aws_tmp05
        jsr     pusha                  ; push command

        lda     aws_tmp04              ; device = final parameter
        jsr     _fujibus_build_packet  ; returns total_len in A/X

        ; SLIP encode:
        ;   aws_tmp00/01 = source pointer
        ;   aws_tmp02/03 = source length

        sta     aws_tmp02              ; pkt_len lo
        stx     aws_tmp03              ; pkt_len hi

        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01

        jsr     _fujibus_slip_encode   ; returns slip_len in A/X

        ; Save slip length for write_serial_data
        sta     aws_tmp02
        stx     aws_tmp03

        jsr     setup_serial_19200

        ; write_serial_data expects:
        ;   aws_tmp00/01 = buffer pointer
        ;   aws_tmp02/03 = length

        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01

        jsr     _write_serial_data
        jmp     restore_output_to_screen


; uint16_t fujibus_receive_packet(void)
_fujibus_receive_packet:
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

        ; if (slip_len == 0) return 0;
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
        jsr     _fujibus_slip_decode

        sta     aws_tmp02              ; dec_len lo
        stx     aws_tmp03              ; dec_len hi

        ; if (dec_len < fujibus_header_size) return 0;
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
