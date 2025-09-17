; Print utilities for FujiNet ROM
        .export  print_string, print_char
        ; .export  print_newline, print_hex_byte
        .import  remember_axy, OSBYTE, OSASCI

        .segment "CODE"

; Print a string terminated by bit 7 set
; String address is on stack, uses ZP $AE $AF $B3
; Exit: AXY preserved, C=0
print_string:
        sta     $B3                 ; Save A
        pla                         ; Get return address
        sta     $AE
        pla
        sta     $AF
        lda     $B3
        pha                         ; Save A & Y
        tya
        pha
        ldy     #0
print_loop:
        jsr     inc_word_AE_and_load
        bmi     print_return1       ; If bit 7 set (end of string)
        jsr     print_char
        bpl     print_loop          ; Always true
print_return1:
        ; check if it's exactly #$80, if so incremement AE 1 more to avoid jumping to an end of string marker
        ; in case next instruction doesn't have high bit set. This allows for string prints followed by JMP, as they can self terminate.
        cmp     #$80
        bne     not_80
        jsr     inc_word_AE_and_load
not_80:
        pla                         ; Restore A & Y
        tay
        pla
print_return2:
        clc
        jmp     ($AE)               ; Return to caller

; Increment word at $AE and load byte
inc_word_AE_and_load:
        inc     $AE
        bne     inc_word_AE_exit
        inc     $AF
inc_word_AE_exit:
        lda     ($AE),y
        rts

; Print a single character
; A = character to print
print_char:
        jsr     remember_axy
        pha
        lda     #$EC                ; OSBYTE 236 - get character destination
        ldx     #0
        ldy     #$FF
        jsr     OSBYTE
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

; ; Print newline (CR only for BBC)
; print_newline:
;         pha
;         lda     #13                 ; CR
;         jsr     print_char
;         pla
;         rts



; ; Print a byte as hex
; ; A = byte to print
; print_hex_byte:
;         pha
;         jsr     print_hex_nibble_high
;         pla
;         jmp     print_hex_nibble_low

; print_hex_nibble_high:
;         pha
;         lsr
;         lsr
;         lsr
;         lsr
;         jsr     print_hex_nibble
;         pla
;         rts

; print_hex_nibble_low:
;         and     #$0F
; print_hex_nibble:
;         cmp     #10
;         bcc     nibble_digit
;         adc     #6
; nibble_digit:
;         adc     #$30
;         jmp     print_char
