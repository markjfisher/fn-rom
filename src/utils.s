        .export  osbyte_X0YFF
        .export  osbyte_YFF
        .export  a_rorx4
        .export  a_rorx3

        .include "mos.inc"

        .segment "CODE"

osbyte_X0YFF:
        ldx     #0
osbyte_YFF:
        ldy     #$FF
        jmp     OSBYTE

a_rorx4:
    LSR     A
a_rorx3:
    LSR     A
    LSR     A
    LSR     A
    RTS
