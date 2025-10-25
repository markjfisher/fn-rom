; Assembly helper functions for serial_u.c
; These provide OSBYTE wrappers for C code
;
; Note: C functions map to _funcname in assembly

        .export _check_rs423_buffer
        .export _read_rs423_char

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; _check_rs423_buffer - Check if RS423 buffer has data
; C prototype: uint8_t check_rs423_buffer(void);
; Returns: A = number of characters in buffer (0-255)
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_check_rs423_buffer:
        ; OSBYTE 128 (0x80), X=254 (RS423 buffer), Y=255
        lda     #$80            ; OSBYTE 128 (READ_ADC)
        ldx     #$FE            ; X = 254 (RS423 input buffer)
        ldy     #$FF            ; Y = 255
        jsr     OSBYTE
        
        ; X now contains number of characters in buffer
        txa                     ; Return in A
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; _read_rs423_char - Read a character from RS423 buffer
; C prototype: uint8_t read_rs423_char(void);
; Returns: A = character read, or 0xFF if none available
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_read_rs423_char:
        ; OSBYTE 145 (0x91), X=1 (RS423), Y=0
        lda     #$91            ; OSBYTE 145 (REMOVE_CHAR)
        ldx     #$01            ; X = 1 (RS423 buffer)
        ldy     #$00            ; Y = 0
        jsr     OSBYTE
        
        ; OSBYTE 145 returns:
        ;   Carry clear: success, character in Y
        ;   Carry set: no character available
        bcs     @no_char
        
        ; Success - character is in Y
        tya                     ; Return character in A
        rts

@no_char:
        ; No character available - return 0xFF
        lda     #$FF
        rts

