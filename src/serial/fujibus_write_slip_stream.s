        .export  fujibus_write_slip_stream

        .import  setup_serial_19200
        .import  restore_output_to_screen

        .include "fujinet.inc"

; write raw buffer as SLIP frame directly to serial
;
; input:
;   aws_tmp00/01 = source pointer
;   aws_tmp02/03 = source length
;
; uses:
;   A, Y, aws_tmp04
;
; output:
;   none

fujibus_write_slip_stream:
        jsr     setup_serial_19200

        lda     #SLIP_END
        jsr     OSWRCH

        ldy     #$00

@loop:
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done

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

@done:
        lda     #SLIP_END
        jsr     OSWRCH
        jmp     restore_output_to_screen
