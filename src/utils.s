        .export  a_rorx3
        .export  a_rorx4
        .export  a_rorx5
        .export  a_rolx4
        .export  a_rolx5
        .export  a_rorx6and3
        .export  a_rorx4and3
        .export  a_rorx2and3
        .export  calculate_crc7
        .export  GSINIT_A
        .export  is_alpha_char
        .export  osbyte_X0YFF
        .export  osbyte_YFF
        .export  set_text_pointer_yx
        .export  tube_check_if_present
        .export  ucasea2
        .export  y_add7
        .export  y_add8

        .include "fujinet.inc"

        .segment "CODE"

osbyte_X0YFF:
        ldx     #0
osbyte_YFF:
        ldy     #$FF
        jmp     OSBYTE

; a_rorx6and3 - Shift A right by 6 bits and mask with 3
; Translated from MMFS lines 589-598
a_rorx6and3:
        lsr     a                       ; Shift right 2 bits
        lsr     a
        ; Fall into a_rorx4and3
a_rorx4and3:
        lsr     a                       ; Shift right 2 more bits (total 4)
        lsr     a
        ; Fall into a_rorx2and3
a_rorx2and3:
        lsr     a                       ; Shift right 2 more bits (total 6)
        lsr     a
        and     #$03                    ; Mask with 3
        rts

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Calculate CRC7
; Exit: A=CRC7, X=0, Y=FF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calculate_crc7:
        ldy     #<(CHECK_CRC7 - VID - 1)
        lda     #$00
@loop1:
        eor     VID,y
        asl     a
        ldx     #$07
@loop2:
        bcc     @c7b7z1
        eor     #$12
@c7b7z1:
        asl     a
        dex
        bne     @loop2
        bcc     @c7b7z2
        eor     #$12
@c7b7z2:
        dey
        bpl     @loop1
        ora     #$01
        rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Tube check if present
; Exit: A=0 if tube present, $FF if not

; from New Advanced User Guide:
;  Before attempting to use any of the Tube routines an OSBYTE call with
;  A=&EA, X=0 and Y=&FF should be made to establish whether a Tube is
;  present on the machine. The X register will be returned with the value
;  &FF if a Tube is present and with zero otherwise.
;
; This function converts the result to A=0 if tube present, $FF if not,
; and sets fuji_tube_present to this value, i.e. "Tube present if this value is zero"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

tube_check_if_present:
        lda     #$EA
        ldx     #$00
        ldy     #$FF
        jsr     OSBYTE
        txa
        eor     #$FF
        sta     fuji_tube_present
        rts

y_add8:
        iny
y_add7:
        iny
        iny
        iny
        iny
        iny
        iny
        iny
        rts

is_alpha_char:
        pha
        and     #$5F
        cmp     #$41
        bcc     @exit1                  ; If <"A"
        cmp     #$5B
        bcc     @exit2                  ; If <="Z"
@exit1:
        sec
@exit2:
        pla
        rts

ucasea2:
        php
        jsr     is_alpha_char
        bcs     @ucasea
        and     #$5F                    ; A = Ucase(A)
@ucasea:
        and     #$7F                    ; Ignore bit 7
        plp
        rts