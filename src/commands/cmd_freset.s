; *FRESET command implementation
; Sends a reset command frame to the FujiNet device via serial
; Frame format: [device_byte, cmd1, cmd2, cmd3, cmd4, cmd5, checksum]
; Reset frame: 70 FF 00 00 00 00 [checksum]

        .export cmd_fs_freset

        .include "fujinet.inc"

        .segment "CODE"

; Serial hardware addresses (from b2 emulator source)
ACIA_CTRL       = $FE08         ; ACIA Control/Status Register
ACIA_DATA       = $FE09         ; ACIA Data Register
SERPROC_CTRL    = $FE10         ; SERPROC Control Register

; ACIA Status bits
ACIA_RDRF       = $01           ; Receive Data Register Full
ACIA_TDRE       = $02           ; Transmit Data Register Empty

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_freset - Handle *FRESET command
; Sends reset command frame to FujiNet device
; Uses cws_tmp1-6 for packet buffer (7 bytes total)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_freset:
        ; Initialize serial hardware
        jsr     init_serial

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

        ; Calculate checksum (sum of device + command bytes)
        ; Checksum = (0x70 + 0xFF + 0x00 + 0x00 + 0x00 + 0x00) & 0xFF
        jsr     calc_checksum
        sta     cws_tmp7        ; Store checksum

        ; Send packet bytes
        ldx     #0              ; Start at byte 0
@send_loop:
        lda     cws_tmp1,x      ; Get byte from buffer
        jsr     send_byte       ; Send it
        inx
        cpx     #7              ; Sent all 7 bytes?
        bne     @send_loop

        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; init_serial - Initialize serial hardware for 19200 baud, 8N1
; Modifies: A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_serial:
        ; Configure SERPROC for 19200 baud
        ; &00 = TX=19200(000), RX=19200(000), Motor=0, RS423=0
        lda     #$00
        sta     SERPROC_CTRL

        ; ACIA: Master reset
        lda     #$03
        sta     ACIA_CTRL

        ; ACIA: 8N1, RTS low, TX int off, RX int on
        ; &15 = %00010101 = 8 bits, no parity, 1 stop, RTS low, RX int on
        lda     #$15
        sta     ACIA_CTRL

        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; calc_checksum - Calculate checksum for packet
; Input: cws_tmp1-6 contain device byte and 5 command bytes
; Output: A = checksum (sum of all 6 bytes, low byte)
; Modifies: A, X
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calc_checksum:
        lda     #0              ; Initialize checksum
        ldx     #0              ; Start at byte 0
@sum_loop:
        clc
        adc     cws_tmp1,x      ; Add byte to checksum
        inx
        cpx     #6              ; Processed all 6 bytes?
        bne     @sum_loop
        ; A now contains checksum (low byte of sum)
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; send_byte - Send a byte via ACIA
; Input: A = byte to send
; Modifies: A (preserved via stack)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

send_byte:
        pha                     ; Save byte to send

@wait_ready:
        lda     ACIA_CTRL       ; Check ACIA status
        and     #ACIA_TDRE      ; Check TDRE bit (ready to transmit)
        beq     @wait_ready     ; Wait until ready

        pla                     ; Restore byte
        sta     ACIA_DATA       ; Send byte
        rts

