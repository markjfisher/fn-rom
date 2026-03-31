        .export  fujibus_write_slip_stream
        .export  fujibus_write_slip_stream_dual

        .import  setup_serial_19200
        .import  restore_output_to_screen

        .include "fujinet.inc"

; SLIP-encode and write one contiguous region (aws_tmp00/01 = ptr, aws_tmp02/03 = len).
; Clobbers A, Y, aws_tmp04.
slip_emit_region:
        ldy     #$00

@loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done_region

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
        beq     @write_esc_end
        cmp     #SLIP_ESCAPE
        beq     @write_esc_esc

        jsr     OSWRCH
        jmp     @loop

@write_esc_end:
        lda     #SLIP_ESCAPE
        jsr     OSWRCH
        lda     #SLIP_ESC_END
        jsr     OSWRCH
        jmp     @loop

@write_esc_esc:
        lda     #SLIP_ESCAPE
        jsr     OSWRCH
        lda     #SLIP_ESC_ESC
        jsr     OSWRCH
        jmp     @loop

@done_region:
        rts

; write raw buffer as SLIP frame directly to serial
;
; input:
;   aws_tmp00/01 = source pointer
;   aws_tmp02/03 = source length
fujibus_write_slip_stream:
        jsr     setup_serial_19200

        lda     #SLIP_END
        jsr     OSWRCH

        jsr     slip_emit_region

        lda     #SLIP_END
        jsr     OSWRCH
        jmp     restore_output_to_screen

; One SLIP frame from two contiguous regions (e.g. header in RAM + sector from data_ptr).
; First region:  aws_tmp00/01 + aws_tmp02/03
; Second region: aws_tmp06/07 + aws_tmp08/09
fujibus_write_slip_stream_dual:
        jsr     setup_serial_19200

        lda     #SLIP_END
        jsr     OSWRCH

        jsr     slip_emit_region

        lda     aws_tmp06
        sta     aws_tmp00
        lda     aws_tmp07
        sta     aws_tmp01
        lda     aws_tmp08
        sta     aws_tmp02
        lda     aws_tmp09
        sta     aws_tmp03

        jsr     slip_emit_region

        lda     #SLIP_END
        jsr     OSWRCH
        jmp     restore_output_to_screen
