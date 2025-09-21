        .export  osbyte_X0YFF
        .export  osbyte_YFF
        .export  a_rorx4
        .export  a_rorx3
        .export  GSINIT_A
        .export  set_text_pointer_yx

        .include "mos.inc"

        .segment "CODE"

osbyte_X0YFF:
        ldx     #0
osbyte_YFF:
        ldy     #$FF
        jmp     OSBYTE

a_rorx4:
        lsr     a
a_rorx3:
        lsr     a
        lsr     a
        lsr     a
        rts

GSINIT_A:
        clc
        jmp     GSINIT

set_text_pointer_yx:
        stx     TextPointer
        sty     TextPointer+1
        ldy     #$00
        rts