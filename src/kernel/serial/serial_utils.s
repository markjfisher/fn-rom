; Serial utility functions for FujiNet commands
; Provides common functions for serial communication

        .export flush_serial
        .export restore_output_to_screen
        .export setup_serial_19200
        .export setup_serial_19200_and_flush

        ; functions used by C
        .export check_rs423_buffer
        .export read_rs423_char

        .importzp cws_tmp1

        .import OSBYTE

        .include "fujinet.inc"

        .segment "CODE"

; OSBYTE constants
OSBYTE_SERIAL_RX_RATE   = $07   ; Set serial receive baud rate
OSBYTE_SERIAL_TX_RATE   = $08   ; Set serial transmit baud rate
OSBYTE_INPUT_STREAM     = $02   ; Set input stream
OSBYTE_FLUSH_BUFFER     = $15   ; Flush buffer
OSBYTE_IN_KEY           = $81   ; Read key with timeout

; Baud rates
; TODO: make this configurable for user
BAUD_19200              = $08   ; 19200 baud

; Stream values
INPUT_SERIAL            = $01   ; Input from serial only
INPUT_KEYBOARD          = $00   ; Input from keyboard only

; Buffer IDs
BUFFER_KEYBOARD         = $00   ; Keyboard buffer
BUFFER_SERIAL_INPUT     = $01   ; Serial input buffer



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; setup_serial_19200 - Configure serial input and baud for FujiNet.
; TX bytes are written directly to the ACIA by fuji_link_write_byte; do not
; redirect MOS output here.
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

setup_serial_19200:
        ; Set RX baud to 19200
        ldx     #BAUD_19200
        ldy     #0
        lda     #OSBYTE_SERIAL_RX_RATE
        jsr     OSBYTE

        ; Set TX baud to 19200
        ldx     #BAUD_19200
        ldy     #0
        lda     #OSBYTE_SERIAL_TX_RATE
        jsr     OSBYTE

        ; Switch input to serial (required for MOS RS423 buffering)
        ldx     #INPUT_SERIAL
        ldy     #0
        lda     #OSBYTE_INPUT_STREAM
        jsr     OSBYTE
        rts

setup_serial_19200_and_flush:
        jsr     setup_serial_19200

flush_serial:
        ; Flush serial input buffer
        ldx     #BUFFER_SERIAL_INPUT
        ldy     #0
        lda     #OSBYTE_FLUSH_BUFFER
        jmp     OSBYTE


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; restore_output_to_screen - Restore MOS input after FujiNet serial I/O.
; Name kept for existing callers; FujiNet TX no longer redirects MOS output.
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

restore_output_to_screen:
        ; Restore input to keyboard
        ldx     #INPUT_KEYBOARD
        ldy     #0
        lda     #OSBYTE_INPUT_STREAM
        jsr     OSBYTE
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; check_rs423_buffer - Check if RS423 buffer has data
; C prototype: uint8_t check_rs423_buffer(void);
; Returns: A = number of characters in buffer (0-255)
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

check_rs423_buffer:
        ; OSBYTE 128 (0x80), X=254 (RS423 buffer), Y=255
        lda     #$80            ; OSBYTE 128 (READ_ADC)
        ldx     #$FE            ; X = 254 (RS423 input buffer)
        ldy     #$FF            ; Y = 255
        jsr     OSBYTE
        
        ; X now contains number of characters in buffer
        txa                     ; Return in A
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read_rs423_char - Read a character from RS423 buffer
; C prototype: uint8_t read_rs423_char(void);
; Returns: A = character read
;          cws_tmp1 is 0 for good read, -1 for error
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_rs423_char:
        ; OSBYTE 145 (0x91), X=1 (RS423), Y=0
        lda     #$91            ; OSBYTE 145 (REMOVE_CHAR)
        ldx     #$01            ; X = 1 (RS423 buffer)
        ldy     #$00            ; Y = 0
        sty     cws_tmp1        ; set result to good in expectation
        jsr     OSBYTE
        
        ; OSBYTE 145 returns:
        ;   Carry clear: success, character in Y
        ;   Carry set: no character available
        bcs     @no_char
        
        ; Success - character is in Y
        tya                     ; Return character in A
        rts

@no_char:
        ; No character available set cws_tmp1 to -1
        dec     cws_tmp1
        rts
