; *FRESET command implementation
; Sends a reset command frame to the FujiNet device via serial
; Frame format: [device_byte, cmd1, cmd2, cmd3, cmd4, cmd5, checksum]
; Reset frame: 70 FF 00 00 00 00 [checksum]

        .export cmd_fs_freset
        .export calc_checksum

        .include "fujinet.inc"

        .segment "CODE"

; OSBYTE constants
OSBYTE_SERIAL_RX_RATE   = $07   ; Set serial receive baud rate
OSBYTE_SERIAL_TX_RATE   = $08   ; Set serial transmit baud rate
OSBYTE_OUTPUT_STREAM    = $03   ; Set output stream
OSBYTE_INPUT_STREAM     = $02   ; Set input stream
OSBYTE_FLUSH_BUFFER     = $15   ; Flush buffer

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
; cmd_fs_freset - Handle *FRESET command
; Sends reset command frame to FujiNet device
; Uses cws_tmp1-6 for packet buffer (7 bytes total)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_freset:
        ; Build packet in workspace
        ; Device byte (0x70)
        lda     #$70
        sta     cws_tmp1

        ; Command bytes (FF 00 00 00 00)
        lda     #$FF
        sta     cws_tmp2
        lda     #$00
        sta     cws_tmp3
        sta     cws_tmp4
        sta     cws_tmp5
        sta     cws_tmp6

        ; Calculate checksum (includes ALL 6 bytes: device + 5 command bytes)
        jsr     calc_checksum
        sta     cws_tmp7        ; Store checksum

        ; Configure serial port via OS calls
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

        ; Send packet bytes using OSWRCH (goes through OS to SERPROC)
        lda     cws_tmp1        ; Send byte 1 (device 0x70)
        jsr     OSWRCH
        lda     cws_tmp2        ; Send byte 2 (0xFF)
        jsr     OSWRCH
        lda     cws_tmp3        ; Send byte 3 (0x00)
        jsr     OSWRCH
        lda     cws_tmp4        ; Send byte 4 (0x00)
        jsr     OSWRCH
        lda     cws_tmp5        ; Send byte 5 (0x00)
        jsr     OSWRCH
        lda     cws_tmp6        ; Send byte 6 (0x00)
        jsr     OSWRCH
        lda     cws_tmp7        ; Send byte 7 (checksum)
        jsr     OSWRCH

        ; Restore output to screen
        ldx     #OUTPUT_SCREEN
        ldy     #0
        lda     #OSBYTE_OUTPUT_STREAM
        jsr     OSBYTE

        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; calc_checksum - Calculate FujiNet checksum for packet
; Algorithm: chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff)
; Input: cws_tmp1-6 contain device byte and 5 command bytes (ALL 6 bytes)
; Output: A = checksum
; Modifies: A, X, aws_tmp00 (low byte), aws_tmp01 (high byte)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calc_checksum:
        lda     #0
        sta     aws_tmp00       ; chk = 0 (only need 8-bit since we collapse after each add)
        ldx     #0              ; Start at byte 0 (include device byte)

@sum_loop:
        ; Compute: chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff)
        ; First compute chk + buf[i] into 16-bit result (aws_tmp01:aws_tmp00)
        clc
        lda     aws_tmp00       ; Get current chk
        adc     cws_tmp1,x      ; Add buffer byte
        sta     aws_tmp00       ; Store low byte of sum
        lda     #0
        adc     #0              ; Capture carry in A
        sta     aws_tmp01       ; Store high byte of sum
        
        ; Now collapse to 8 bits: chk = high_byte + low_byte
        clc
        lda     aws_tmp00       ; Get low byte
        adc     aws_tmp01       ; Add high byte
        sta     aws_tmp00       ; Store result (may be > 255, but we only keep low 8 bits)
        
        inx
        cpx     #6              ; Processed all 6 bytes? (cws_tmp1 to cws_tmp6)
        bne     @sum_loop       ; No, continue
        
        lda     aws_tmp00       ; Return result in A
        rts

