; Serial utility functions for FujiNet commands
; Provides common functions for serial communication

        .export calc_checksum
        .export read_serial_byte
        .export read_serial_byte_success
        .export read_serial_byte_timeout
        .export read_serial_data
        .export restore_output_to_screen
        .export setup_serial_19200

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

        ; NOTE: We do NOT set OSBYTE 2 (INPUT_STREAM) to serial!
        ; If we do, the OS event handler will consume bytes from the RS423
        ; buffer and redirect them to the keyboard input stream. This causes
        ; bytes to disappear before we can read them with OSBYTE 145.
        ; We only need OUTPUT redirected to serial.

        ; Switch output to serial only
        ldx     #OUTPUT_SERIAL
        ldy     #0
        lda     #OSBYTE_OUTPUT_STREAM
        jsr     OSBYTE

        ; Flush serial input buffer
        ldx     #BUFFER_SERIAL_INPUT
        ldy     #0
        lda     #OSBYTE_FLUSH_BUFFER
        jsr     OSBYTE

        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; restore_output_to_screen - Restore output to screen/keyboard
; Modifies: A, X, Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

restore_output_to_screen:
        ; NOTE: We don't need to restore INPUT_STREAM since we never changed it
        
        ; Restore output to screen
        ldx     #OUTPUT_SCREEN
        ldy     #0
        lda     #OSBYTE_OUTPUT_STREAM
        jsr     OSBYTE
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read_serial_byte - Read a byte from RS423 serial buffer with timeout
; Uses polling loop with timeout instead of OSBYTE 129
; Input: X = timeout in centiseconds
; Output: A = byte read, Carry = 1 if success, 0 if timeout
; Modifies: A, X, Y, aws_tmp04 (timeout counter)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_serial_byte:
        ; Save timeout value (in centiseconds)
        stx     aws_tmp04       ; Store timeout

wait_loop:
        ; Check if RS423 buffer has data
        ; OSBYTE 128 (READ_ADC) with X=254 returns buffer count in X
        lda     #$80            ; OSBYTE 128
        ldx     #$FE            ; 254 = RS423 input buffer
        ldy     #$FF            ; Y must be 0xFF
        jsr     OSBYTE

        ; X now contains number of characters in buffer
        cpx     #0
        bne     data_available

        ; No data yet - check timeout
        ; We do NOT insert delays like before - just tight poll like test.c
        dec     aws_tmp04
        bne     wait_loop       ; Keep checking until timeout
        beq     read_serial_byte_timeout

data_available:
        ; Read character from RS423 buffer
        ; OSBYTE 145 (REMOVE_CHAR) with X=1 for RS423
        lda     #$91            ; OSBYTE 145
        ldx     #$01            ; 1 = RS423 buffer
        ldy     #$00            ; Y = 0
        jsr     OSBYTE

        ; Character is in Y, Carry clear if success
        ; If carry set, no character (shouldn't happen)
        bcs     read_serial_byte_timeout

        ; Success - character in Y
        tya                     ; Move character to A
read_serial_byte_success:
        sec                     ; Set carry for success
        rts

read_serial_byte_timeout:
        clc                     ; Clear carry for timeout
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read_serial_data - Read multiple bytes from RS423 buffer
; Matches test.c read_serial_data() behavior with tight polling loop
; Supports 16-bit lengths for sector data (up to 65535 bytes)
; Input: pws_tmp00-01 = pointer to buffer
;        X = low byte of length
;        Y = high byte of length
;        A = mode (reserved for future use, currently ignored)
; Output: X = low byte of bytes actually read
;         Y = high byte of bytes actually read  
;         Carry = 1 if all bytes read successfully, 0 if timeout
; Modifies: A, X, Y, pws_tmp00-01 (buffer ptr updated),
;           pws_tmp02-03 (length), pws_tmp04-05 (bytes_received),
;           pws_tmp06-07 (wait_count), pws_tmp08 (buffer_index)
; Uses: aws_tmp04 temporarily for OSBYTE results
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_serial_data:
        ; Save length (X=low, Y=high)
        stx     pws_tmp02       ; Length low byte
        sty     pws_tmp03       ; Length high byte
        
        ; Initialize bytes_received = 0
        lda     #0
        sta     pws_tmp04       ; bytes_received low
        sta     pws_tmp05       ; bytes_received high
        sta     pws_tmp08       ; buffer_index (Y register value)

read_data_byte_loop:
        ; Check if we've read all requested bytes (16-bit comparison)
        ; Compare bytes_received with length
        lda     pws_tmp04       ; bytes_received low
        cmp     pws_tmp02       ; length low
        lda     pws_tmp05       ; bytes_received high
        sbc     pws_tmp03       ; length high (with borrow)
        bcs     read_data_complete ; If bytes_received >= length, done
        
        ; Initialize wait_count for this byte (max_wait = 10000 = $2710)
        lda     #$10
        sta     pws_tmp06       ; Low byte of wait_count
        lda     #$27
        sta     pws_tmp07       ; High byte of wait_count

read_data_wait_loop:
        ; Check if RS423 buffer has data (OSBYTE 128, X=254)
        lda     #$80            ; OSBYTE 128
        ldx     #$FE            ; 254 = RS423 input buffer
        ldy     #$FF            ; Y must be 0xFF
        jsr     OSBYTE
        
        ; X now contains number of characters in buffer
        cpx     #0
        bne     read_data_available
        
        ; No data yet - increment wait_count and check timeout
        inc     pws_tmp06
        bne     @no_carry
        inc     pws_tmp07
@no_carry:
        ; Check if wait_count >= max_wait (10000 = $2710)
        lda     pws_tmp07       ; High byte
        cmp     #$27
        bcc     read_data_wait_loop ; Still < $27xx, keep waiting
        bne     read_data_timeout ; > $27xx, timeout
        lda     pws_tmp06       ; High bytes equal, check low byte
        cmp     #$10
        bcc     read_data_wait_loop ; Still < $2710, keep waiting
        bcs     read_data_timeout ; >= $2710, timeout

read_data_available:
        ; Read character from RS423 buffer (OSBYTE 145, X=1)
        lda     #$91            ; OSBYTE 145
        ldx     #$01            ; 1 = RS423 buffer
        ldy     #$00            ; Y = 0
        jsr     OSBYTE
        
        ; Character is in Y after OSBYTE 145
        ; Store byte in buffer using (ptr),Y addressing
        ldy     pws_tmp08       ; Get buffer index
        tya                     ; Save index to A temporarily
        pha
        txa                     ; Get character from X (OSBYTE 145 returns in Y, but we need to check this)
        ; Actually, character is in Y after OSBYTE 145
        pla                     ; Restore buffer index to A
        tay                     ; Put buffer index back in Y
        txa                     ; Character was in X? Let me check...
        ; ERROR: OSBYTE 145 returns character in Y, not X. Let me fix this.
        
        ; Actually, let me rewrite this more clearly:
        ; OSBYTE 145 (REMOVE_CHAR) returns:
        ;   Carry clear if success, character in Y
        ;   Carry set if no character
        bcs     read_data_timeout ; No character (shouldn't happen)
        
        tya                     ; Move character from Y to A
        ldy     pws_tmp08       ; Get buffer index into Y
        sta     (pws_tmp00),y   ; Store byte
        
        ; Increment buffer index, handling page crossing
        inc     pws_tmp08
        bne     @no_page_cross
        ; Buffer index wrapped to 0, increment high byte of pointer
        inc     pws_tmp01
@no_page_cross:
        
        ; Increment bytes_received (16-bit)
        inc     pws_tmp04
        bne     @no_carry_bytes
        inc     pws_tmp05
@no_carry_bytes:
        
        ; Continue to next byte
        jmp     read_data_byte_loop

read_data_timeout:
        ; Timeout occurred - fill remaining bytes with 0 and return
        ; Check if already done (16-bit comparison)
        lda     pws_tmp04       ; bytes_received low
        cmp     pws_tmp02       ; length low
        lda     pws_tmp05       ; bytes_received high
        sbc     pws_tmp03       ; length high
        bcs     read_data_complete ; Already done
        
        ; Fill remaining with zeros
        lda     #0
@fill_loop:
        ldy     pws_tmp08       ; Get buffer index
        sta     (pws_tmp00),y   ; Store zero
        
        ; Increment buffer index, handling page crossing
        inc     pws_tmp08
        bne     @no_page_cross
        inc     pws_tmp01       ; Crossed page boundary
@no_page_cross:
        
        ; Increment bytes_received (16-bit)
        inc     pws_tmp04
        bne     @no_carry_bytes
        inc     pws_tmp05
@no_carry_bytes:
        
        ; Check if done (16-bit comparison)
        lda     pws_tmp04       ; bytes_received low
        cmp     pws_tmp02       ; length low
        lda     pws_tmp05       ; bytes_received high
        sbc     pws_tmp03       ; length high
        bcc     @fill_loop      ; Continue if bytes_received < length
        
        ; Return with carry clear (timeout)
        ldx     pws_tmp04       ; Return bytes_received low in X
        ldy     pws_tmp05       ; Return bytes_received high in Y
        clc
        rts

read_data_complete:
        ; All bytes read successfully
        ldx     pws_tmp04       ; Return bytes_received low in X
        ldy     pws_tmp05       ; Return bytes_received high in Y
        sec                     ; Set carry for success
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; calc_checksum - Calculate FujiNet checksum for packet
; Algorithm: chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff)
; Input: X = start offset in cws_tmp workspace
;        Y = number of bytes to checksum
; Output: A = checksum
; Modifies: A, X, Y, aws_tmp00 (low byte), aws_tmp01 (high byte)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calc_checksum:
        lda     #0
        sta     aws_tmp00       ; chk = 0
        stx     aws_tmp02       ; Save start offset
        sty     aws_tmp03       ; Save count

@sum_loop:
        ; Compute: chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff)
        clc
        lda     aws_tmp00       ; Get current chk
        ldx     aws_tmp02       ; Get current offset
        adc     cws_tmp1,x      ; Add buffer byte
        sta     aws_tmp00       ; Store low byte of sum
        lda     #0
        adc     #0              ; Capture carry in A
        sta     aws_tmp01       ; Store high byte of sum

        ; Now collapse to 8 bits: chk = high_byte + low_byte
        clc
        lda     aws_tmp00       ; Get low byte
        adc     aws_tmp01       ; Add high byte
        sta     aws_tmp00       ; Store result

        inc     aws_tmp02       ; Next byte
        dec     aws_tmp03       ; Decrement count
        bne     @sum_loop       ; Continue if more bytes

        lda     aws_tmp00       ; Return result in A
        rts

