;
; Replay SLIP-framed FujiBus responses for unit tests.
; DSL loads a capture file at mock_slip_base ($C000) and sets mock_slip_len.
;
        .export  mock_slip_base
        .export  mock_slip_len
        .export  mock_slip_pos
        .export  mock_slip_rewind
        .export  osbyte_80
        .export  osbyte_91

        .segment "ZEROPAGE"
mock_slip_ptr:  .res    2

        .segment "CODE"

MOCK_SLIP_BASE_ADDR     = $C000

mock_slip_base:
        .word   MOCK_SLIP_BASE_ADDR
mock_slip_len:
        .word   0
mock_slip_pos:
        .word   0

mock_slip_rewind:
        lda     #$00
        sta     mock_slip_pos
        sta     mock_slip_pos+1
        rts

; OSBYTE $80 — check RS423 buffer (X=$FE, Y=$FF); returns count in X.
osbyte_80:
        cpx     #$FE
        bne     osbyte_80_done
        ldx     #$00
        lda     mock_slip_pos
        cmp     mock_slip_len
        lda     mock_slip_pos+1
        sbc     mock_slip_len+1
        bcc     osbyte_80_has
        beq     @check_eq
        jmp     osbyte_80_done
@check_eq:
        lda     mock_slip_pos
        cmp     mock_slip_len
        bcs     osbyte_80_done
osbyte_80_has:
        ldx     #$01
osbyte_80_done:
        rts

; OSBYTE $91 — read RS423 (X=1, Y=0); character in Y, C clear on success.
osbyte_91:
        cpx     #$01
        bne     @no_char
        lda     mock_slip_pos
        cmp     mock_slip_len
        lda     mock_slip_pos+1
        sbc     mock_slip_len+1
        bcc     @read
        bne     @no_char
        lda     mock_slip_pos
        cmp     mock_slip_len
        bcs     @no_char
@read:
        lda     mock_slip_base
        sta     mock_slip_ptr
        lda     mock_slip_base+1
        sta     mock_slip_ptr+1
        ldy     mock_slip_pos
        lda     (mock_slip_ptr),y
        pha
        inc     mock_slip_pos
        bne     @no_inc_hi
        inc     mock_slip_pos+1
@no_inc_hi:
        pla
        tay
        clc
        rts

@no_char:
        sec
        rts
