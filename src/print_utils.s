; Print utilities for FujiNet ROM
        .export print_string, print_char, print_newline, print_hex_byte
        .import remember_axy, OSBYTE, OSASCI

        .segment "CODE"

; Print a null-terminated string
; A = low byte of string address
; X = high byte of string address
print_string:
        sta     $AE                 ; Use BBC filing system workspace
        stx     $AF
        ldy     #0
print_loop:
        lda     ($AE),y
        beq     print_done
        jsr     print_char
        iny
        bne     print_loop
print_done:
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
        ora     #$10
        jsr     osbyte03_output_stream ; Disable spooled output
        pla
        tax
        pla
        jsr     OSASCI              ; Output character
        jmp     osbyte03_restore_stream ; Restore previous setting

; Print newline (CR only for BBC)
print_newline:
        pha
        lda     #13                 ; CR
        jsr     print_char
        pla
        rts

; Print a byte as hex
; A = byte to print
print_hex_byte:
        pha
        jsr     print_hex_nibble_high
        pla
        jmp     print_hex_nibble_low

print_hex_nibble_high:
        pha
        lsr
        lsr
        lsr
        lsr
        jsr     print_hex_nibble
        pla
        rts

print_hex_nibble_low:
        and     #$0F
print_hex_nibble:
        cmp     #10
        bcc     nibble_digit
        adc     #6
nibble_digit:
        adc     #$30
        jmp     print_char

; OSBYTE 3 - Set output stream
; A = stream value
osbyte03_output_stream:
        lda     #3
        ldx     #0
        ldy     #$FF
        jmp     OSBYTE

; OSBYTE 3 - Restore output stream
; X = previous stream value
osbyte03_restore_stream:
        lda     #3
        ldy     #$FF
        jmp     OSBYTE

; OSBYTE 236 - Get character destination
; Returns X = destination
osbyte_236:
        lda     #$EC
        ldx     #0
        ldy     #$FF
        jmp     OSBYTE
