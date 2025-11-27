; Serial utility functions for FujiNet commands
; Provides common functions for serial communication

        .export flush_serial
        .export read_1
        .export restore_output_to_screen
        .export setup_serial_19200

        ; functions used by C
        .export _check_rs423_buffer
        .export _read_rs423_char

        .import err_bad_response
        .import _read_serial_data

        .include "fujinet.inc"

        .segment "CODE"

; OSBYTE constants
OSBYTE_SERIAL_RX_RATE   = $07   ; Set serial receive baud rate
OSBYTE_SERIAL_TX_RATE   = $08   ; Set serial transmit baud rate
OSBYTE_OUTPUT_STREAM    = $03   ; Set output stream
OSBYTE_INPUT_STREAM     = $02   ; Set input stream
OSBYTE_FLUSH_BUFFER     = $15   ; Flush buffer
OSBYTE_IN_KEY           = $81   ; Read key with timeout

; Baud rates
; TODO: make this configurable for user
BAUD_19200              = $08   ; 19200 baud

; Stream values
OUTPUT_SERIAL           = $03   ; Output to serial only
OUTPUT_SCREEN           = $00   ; Output to screen only
INPUT_SERIAL            = $01   ; Input from serial only
INPUT_KEYBOARD          = $00   ; Input from keyboard only

; Buffer IDs
BUFFER_KEYBOARD         = $00   ; Keyboard buffer
BUFFER_SERIAL_INPUT     = $01   ; Serial input buffer



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; setup_serial_19200 - Configure serial port for 19200 baud
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

        ; Switch input to serial (required for RS423 buffer to work properly)
        ldx     #INPUT_SERIAL
        ldy     #0
        lda     #OSBYTE_INPUT_STREAM
        jsr     OSBYTE

        ; Switch output to serial only
        ldx     #OUTPUT_SERIAL
        ldy     #0
        lda     #OSBYTE_OUTPUT_STREAM
        jsr     OSBYTE
        ; ... drop through to flush

flush_serial:
        ; Flush serial input buffer
        ldx     #BUFFER_SERIAL_INPUT
        ldy     #0
        lda     #OSBYTE_FLUSH_BUFFER
        jmp     OSBYTE


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; restore_output_to_screen - Restore output to screen/keyboard
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

restore_output_to_screen:
        ; Restore output to screen
        ldx     #OUTPUT_SCREEN
        ldy     #0
        lda     #OSBYTE_OUTPUT_STREAM
        jsr     OSBYTE
        
        ; Restore input to keyboard
        ldx     #INPUT_KEYBOARD
        ldy     #0
        lda     #OSBYTE_INPUT_STREAM
        jsr     OSBYTE
        rts

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
; Returns: A = character read
;          cws_tmp1 is 0 for good read, -1 for error
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_read_rs423_char:
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


read_1:
        ; wait for rs232 buffer to say there's a byte, and read it. timeout if too long
        ; assumes the serial is active so it doesn't expunge anything.
        ; setup buffer for 1 byte at aws_tmp06
        lda     #<aws_tmp06
        sta     aws_tmp00
        lda     #>aws_tmp06
        sta     aws_tmp01
        lda     #$01
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jsr     _read_serial_data
        bne     @ok
        jmp     err_bad_response

@ok:
        lda     aws_tmp06
        rts
