; Print utilities for FujiNet ROM
        .export  print_char
        .export  print_newline
        .export  print_string
        .export  print_string_ax

        .import  osbyte_X0YFF
        .import  remember_axy

        .include "mos.inc"

        .segment "CODE"

; Print newline
print_newline:
        pha
        lda     #$0D
        jsr     print_char
        pla
        rts


; Print a string terminated by bit 7 set (MMFS style)
; String address is on stack, uses ZP $AE $AF $B3
; Exit: AXY preserved, C=0
print_string:
        sta     aws_tmp03               ; Save A
        pla                             ; Get return address
        sta     cws_tmp7
        pla
        sta     cws_tmp8
        lda     cws_tmp3
        pha                             ; Save A & Y
        tya
        pha
        ldy     #0
print_loop:
        jsr     inc_cws0708_and_load
        bmi     print_return1           ; If bit 7 set (end of string)
        jsr     print_char
        bpl     print_loop              ; Always true
print_return1:
        ; check if it's exactly #$80, if so incremement AE 1 more to avoid jumping to an end of string marker
        ; in case next instruction doesn't have high bit set. This allows for string prints followed by JMP, as they can self terminate.
        cmp     #$80
        bne     @not_80
        jsr     inc_cws0708_and_load
@not_80:
        pla                             ; Restore A & Y
        tay
        pla
print_return2:
        clc
        jmp     (cws_tmp7)              ; Return to caller

; Print a string terminated by bit 7 set, or 00 using A/X as address
; A = low byte of string address
; X = high byte of string address
; Exit: AXY preserved
print_string_ax:
        sta     cws_tmp7
        stx     cws_tmp8
        pha                             ; Save A/X/Y
        txa
        pha
        tya
        pha
        ldy     #0
@loop:
        lda     (cws_tmp7),y
        bmi     @done                   ; If bit 7 set (end of string) - TODO: do we ever use this?
        beq     @done                   ; If 00 set (end of string)
        jsr     print_char
        iny
        bne     @loop
@done:
        pla                             ; Restore A/X/Y
        tay
        pla
        tax
        pla
        rts

; Increment word at $AE/cws_tmp07 and load byte
inc_cws0708_and_load:
        inc     cws_tmp7
        bne     @exit
        inc     cws_tmp8
@exit:
        lda     (cws_tmp7),y
        rts

; Print a single character
; A = character to print
print_char:
        jsr     remember_axy
        pha
        lda     #$EC                ; OSBYTE 236 - get character destination
        jsr     osbyte_X0YFF

        txa                         ; X contains destination
        pha
        ora     #$10                ; Force bit 4 (disable spooled output)
        tax
        jsr     osbyte03_Xoutstream ; Disable spooled output

        pla
        tax
        pla
        jsr     OSASCI              ; Output character
        ; Restore previous setting, ... fall through

osbyte03_Xoutstream:
        lda     #3
        jmp     OSBYTE
