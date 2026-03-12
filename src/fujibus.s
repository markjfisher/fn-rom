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

        ; .export _fujibus_slip_encode
        ; .export _fujibus_slip_decode
        .export _fujibus_send_packet
        .export _fujibus_receive_packet

fujibus_header_size = 6


; ; _fujibus_slip_encode
; ;   Input:
; ;     aws_tmp00/01 = source pointer
; ;     aws_tmp02/03 = source length
; ;   Output:
; ;     fuji_data_buffer = SLIP-encoded frame
; ;     A/X = encoded length (16-bit)
; ;   Uses:
; ;     aws_tmp04 = current input byte
; ;     aws_tmp08/09 = encoded output pointer

; _fujibus_slip_encode:
;         lda     aws_tmp04
;         pha
;         lda     aws_tmp08
;         pha
;         lda     aws_tmp09
;         pha

;         jsr     fujibus_slip_encode_impl

;         sta     fuji_ax_save
;         stx     fuji_ax_save+1

;         pla
;         sta     aws_tmp09
;         pla
;         sta     aws_tmp08
;         pla
;         sta     aws_tmp04

;         ldx     fuji_ax_save+1
;         lda     fuji_ax_save
;         rts


; fujibus_slip_encode_impl:
;         lda     #<fuji_data_buffer
;         sta     aws_tmp08
;         lda     #>fuji_data_buffer
;         sta     aws_tmp09

;         ldy     #$00
;         lda     #SLIP_END
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     :+
;         inc     aws_tmp09
; :

; @encode_loop:
;         lda     aws_tmp02
;         ora     aws_tmp03
;         beq     @encode_done

;         lda     (aws_tmp00),y
;         sta     aws_tmp04

;         inc     aws_tmp00
;         bne     :+
;         inc     aws_tmp01
; :
;         lda     aws_tmp02
;         bne     :+
;         dec     aws_tmp03
; :
;         dec     aws_tmp02

;         lda     aws_tmp04
;         cmp     #SLIP_END
;         beq     @escape_end
;         cmp     #SLIP_ESCAPE
;         beq     @escape_escape

;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     @encode_loop
;         inc     aws_tmp09
;         jmp     @encode_loop

; @escape_end:
;         lda     #SLIP_ESCAPE
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     :+
;         inc     aws_tmp09
; :
;         lda     #SLIP_ESC_END
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     @encode_loop
;         inc     aws_tmp09
;         jmp     @encode_loop

; @escape_escape:
;         lda     #SLIP_ESCAPE
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     :+
;         inc     aws_tmp09
; :
;         lda     #SLIP_ESC_ESC
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     @encode_loop
;         inc     aws_tmp09
;         jmp     @encode_loop

; @encode_done:
;         lda     #SLIP_END
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     :+
;         inc     aws_tmp09
; :
;         lda     aws_tmp08
;         sec
;         sbc     #<fuji_data_buffer
;         pha

;         lda     aws_tmp09
;         sbc     #>fuji_data_buffer
;         tax

;         pla
;         rts

; ; _fujibus_slip_decode
; ;   Input:
; ;     aws_tmp00/01 = pointer to SLIP-encoded buffer
; ;     aws_tmp02/03 = encoded length
; ;   Output:
; ;     fuji_data_buffer = decoded packet
; ;     A/X = decoded length, or 0 on error
; ;   Uses:
; ;     aws_tmp04/05 = scratch
; ;     aws_tmp08/09 = decoded output pointer

; _fujibus_slip_decode:
;         lda     aws_tmp04
;         pha
;         lda     aws_tmp05
;         pha
;         lda     aws_tmp08
;         pha
;         lda     aws_tmp09
;         pha

;         jsr     fujibus_slip_decode_impl

;         sta     fuji_ax_save
;         stx     fuji_ax_save+1

;         pla
;         sta     aws_tmp09
;         pla
;         sta     aws_tmp08
;         pla
;         sta     aws_tmp05
;         pla
;         sta     aws_tmp04

;         ldx     fuji_ax_save+1
;         lda     fuji_ax_save
;         rts


; fujibus_slip_decode_impl:
;         lda     aws_tmp03
;         bne     @check_markers
;         lda     aws_tmp02
;         cmp     #$02
;         bcs     @check_markers
;         lda     #$00
;         tax
;         rts

; @check_markers:
;         ldy     #$00

;         lda     (aws_tmp00),y
;         cmp     #SLIP_END
;         beq     :+
;         lda     #$00
;         tax
;         rts
; :
;         lda     aws_tmp00
;         clc
;         adc     aws_tmp02
;         sta     aws_tmp04
;         lda     aws_tmp01
;         adc     aws_tmp03
;         sta     aws_tmp05

;         lda     aws_tmp04
;         sec
;         sbc     #$01
;         sta     aws_tmp04
;         lda     aws_tmp05
;         sbc     #$00
;         sta     aws_tmp05

;         lda     (aws_tmp04),y
;         cmp     #SLIP_END
;         beq     :+
;         lda     #$00
;         tax
;         rts
; :
;         inc     aws_tmp00
;         bne     :+
;         inc     aws_tmp01
; :
;         lda     aws_tmp02
;         sec
;         sbc     #$02
;         sta     aws_tmp02
;         lda     aws_tmp03
;         sbc     #$00
;         sta     aws_tmp03

;         lda     #<fuji_data_buffer
;         sta     aws_tmp08
;         lda     #>fuji_data_buffer
;         sta     aws_tmp09

; @decode_loop:
;         lda     aws_tmp02
;         ora     aws_tmp03
;         beq     @decode_done

;         lda     (aws_tmp00),y
;         sta     aws_tmp04

;         inc     aws_tmp00
;         bne     :+
;         inc     aws_tmp01
; :
;         lda     aws_tmp02
;         bne     :+
;         dec     aws_tmp03
; :
;         dec     aws_tmp02

;         lda     aws_tmp04
;         cmp     #SLIP_ESCAPE
;         beq     @handle_escape
;         cmp     #SLIP_END
;         bne     :+
;         lda     #$00                  ; unexpected END inside frame
;         tax
;         rts
; :
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     @decode_loop
;         inc     aws_tmp09
;         jmp     @decode_loop

; @handle_escape:
;         lda     aws_tmp02
;         ora     aws_tmp03
;         beq     @decode_error         ; ESC cannot be final interior byte

;         lda     (aws_tmp00),y
;         sta     aws_tmp04

;         inc     aws_tmp00
;         bne     :+
;         inc     aws_tmp01
; :
;         lda     aws_tmp02
;         bne     :+
;         dec     aws_tmp03
; :
;         dec     aws_tmp02

;         lda     aws_tmp04
;         cmp     #SLIP_ESC_END
;         beq     :+
;         cmp     #SLIP_ESC_ESC
;         beq     :++
;         jmp     @decode_error         ; invalid escape sequence
; :
;         lda     #SLIP_END
;         jmp     @store_decoded
; :
;         lda     #SLIP_ESCAPE

; @store_decoded:
;         sta     (aws_tmp08),y
;         inc     aws_tmp08
;         bne     @decode_loop
;         inc     aws_tmp09
;         jmp     @decode_loop

; @decode_done:
;         lda     aws_tmp08
;         sec
;         sbc     #<fuji_data_buffer
;         pha

;         lda     aws_tmp09
;         sbc     #>fuji_data_buffer
;         tax

;         pla
;         rts

; @decode_error:
;         lda     #$00
;         tax
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
        sta     fuji_data_buffer+1

        ; device -> tx buffer[0]
        jsr     popa
        sta     fuji_data_buffer+0

        ; destination pointer = tx buffer + header size
        lda     #<(fuji_data_buffer + fujibus_header_size)
        sta     aws_tmp08
        lda     #>(fuji_data_buffer + fujibus_header_size)
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
        ; total_len = current dest ptr - fuji_data_buffer
        lda     aws_tmp08
        sec
        sbc     #<fuji_data_buffer
        sta     aws_tmp02
        sta     fuji_data_buffer+2      ; length low

        lda     aws_tmp09
        sbc     #>fuji_data_buffer
        sta     aws_tmp03
        sta     fuji_data_buffer+3      ; length high

        ; checksum placeholder + descriptor
        lda     #$00
        sta     fuji_data_buffer+4
        sta     fuji_data_buffer+5

        ; checksum over tx buffer
        lda     #<fuji_data_buffer
        sta     aws_tmp00
        lda     #>fuji_data_buffer
        sta     aws_tmp01
        ; aws_tmp02/03 already = total_len
        jsr     calc_checksum
        sta     fuji_data_buffer+4

        ; stream tx buffer as SLIP directly to serial
        lda     #<fuji_data_buffer
        sta     aws_tmp00
        lda     #>fuji_data_buffer
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
        ; receive and decode SLIP directly into fuji_data_buffer
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
        ; chk_received = rx[4]
        lda     fuji_data_buffer+4
        sta     aws_tmp04

        ; rx[4] = 0
        lda     #$00
        sta     fuji_data_buffer+4

        ; preserve dec_len across calc_checksum
        lda     aws_tmp02
        sta     aws_tmp10
        lda     aws_tmp03
        sta     aws_tmp11

        ; calc_checksum(fuji_data_buffer, dec_len)
        lda     #<fuji_data_buffer
        sta     aws_tmp00
        lda     #>fuji_data_buffer
        sta     aws_tmp01
        lda     aws_tmp10
        sta     aws_tmp02
        lda     aws_tmp11
        sta     aws_tmp03
        jsr     calc_checksum

        cmp     aws_tmp04
        beq     :+

        ; checksum mismatch
        lda     aws_tmp04
        sta     fuji_data_buffer+4
        jmp     @fail

:
        ; restore original checksum byte
        lda     aws_tmp04
        sta     fuji_data_buffer+4

        lda     aws_tmp10
        ldx     aws_tmp11
        rts

@fail:
        lda     #$00
        tax
        rts
