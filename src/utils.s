        .export  a_rorx3
        .export  a_rorx4
        .export  a_rorx5
        .export  a_rolx4
        .export  a_rolx5
        .export  GSINIT_A
        .export  GSREAD_A
        .export  osbyte_X0YFF
        .export  osbyte_YFF
        .export  set_text_pointer_yx

        .import  err_bad

        .include "mos.inc"

        .segment "CODE"

osbyte_X0YFF:
        ldx     #0
osbyte_YFF:
        ldy     #$FF
        jmp     OSBYTE

a_rorx5:
        lsr     a
a_rorx4:
        lsr     a
a_rorx3:
        lsr     a
        lsr     a
        lsr     a
        rts

a_rolx5:
        asl     a
a_rolx4:
        asl     a
        asl     a
        asl     a
        asl     a
        rts

GSINIT_A:
        clc
        jmp     GSINIT

set_text_pointer_yx:
        stx     TextPointer
        sty     TextPointer+1
        ldy     #$00
        rts

err_bad_name:
        jsr     err_bad
        .byte   $CC
        .byte   "name", 0

GSREAD_A:
        jsr     GSREAD
        php
        and     #$7F
        cmp     #$0D        ; Return?
        beq     @exit
        cmp     #$20        ; Control character? (I.e. <&20)
        bcc     err_bad_name
        cmp     #$7F        ; Backspace?
        beq     err_bad_name
@exit:
        plp
        rts
