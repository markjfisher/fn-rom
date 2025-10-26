; *FRESET command implementation
; Sends a reset command frame to the FujiNet device via serial
; Frame format: [device_byte, cmd1, cmd2, cmd3, cmd4, cmd5, checksum]
; Reset frame: 70 FF 00 00 00 00 [checksum]
; Response: 'A' (ACK), 'C' (Complete)

        .export cmd_fs_freset
        .export freset_send_complete
        .export freset_read_ack
        .export freset_read_complete
        .export freset_exit
        .export freset_timeout
        .export freset_invalid_ack
        .export freset_invalid_complete
        .export freset_finish

        .export micro_pause_end
        .export micro_pause_start

        .include "fujinet.inc"

        .segment "CODE"

; Import serial utilities
        .import setup_serial_19200
        .import restore_output_to_screen
        .import _read_serial_data
        .import calc_checksum

; OSBYTE constants
OSBYTE_USER_FLAG        = $01   ; Set user flag

; Error codes
ERR_TIMEOUT             = $01   ; Timeout waiting for response
ERR_INVALID_ACK         = $02   ; Did not receive 'A' (ACK)
ERR_INVALID_COMPLETE    = $03   ; Did not receive 'C' (Complete)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_freset - Handle *FRESET command
; Sends reset command frame to FujiNet device
; Uses cws_tmp1-6 for packet buffer (7 bytes total)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_freset:
        ; Configure serial port
        jsr     setup_serial_19200

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

        ; Calculate checksum (offset 0, 6 bytes)
        ldx     #0              ; Start at cws_tmp1 (offset 0)
        ldy     #6              ; 6 bytes total
        jsr     calc_checksum
        sta     cws_tmp7        ; Store checksum


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

freset_send_complete:

micro_pause_start:

        ; Add delay to let OS process incoming bytes
        ldx     #10             ; (1/50)s x 10 syncs = 0.2 seconds
@delay:
        txa
        pha
        lda     #$13             ; OSBYTE 19 - Wait for vertical sync
        jsr     OSBYTE
        pla
        tax
        dex
        bne     @delay
micro_pause_end:

        ; Read response - expect 'A' (ACK) and 'C' (Complete)
        ; Use read_serial_data to read 2 bytes into pws_tmp09-10
        
        ; Set up buffer pointer to pws_tmp09
        lda     #<pws_tmp09
        sta     pws_tmp00       ; Buffer pointer low
        lda     #>pws_tmp09
        sta     pws_tmp01       ; Buffer pointer high
        
        ; Call read_serial_data - must set pws_tmp02/03 (length) before calling
        ; C function takes NO parameters - all inputs via ZP variables
        lda     #2              ; Read 2 bytes
        sta     pws_tmp02       ; Length low
        lda     #0
        sta     pws_tmp03       ; Length high
        jsr     _read_serial_data
freset_read_ack:
        ; Check if we got 2 bytes (returned in pws_tmp04/05)
        lda     pws_tmp04       ; bytes_received low
        cmp     #2
        bne     freset_timeout  ; Didn't get 2 bytes = timeout
        lda     pws_tmp05       ; bytes_received high
        bne     freset_timeout  ; High byte should be 0
        
        ; Check for 'A' (ACK)
        lda     pws_tmp09       ; First byte
        cmp     #'A'
        bne     freset_invalid_ack
        
freset_read_complete:
        ; Check for 'C' (Complete)
        lda     pws_tmp10       ; Second byte
        cmp     #'C'
        bne     freset_invalid_complete
        
        ; Success! Set exit code to 0
        lda     #0
        beq     freset_exit

freset_timeout:
        lda     #ERR_TIMEOUT
        bne     freset_exit

freset_invalid_ack:
        lda     #ERR_INVALID_ACK
        bne     freset_exit

freset_invalid_complete:
        lda     #ERR_INVALID_COMPLETE
        ; Fall through to freset_exit

freset_exit:
        ; Save exit code on stack (A will be trashed by restore_output_to_screen)
        pha
        
        ; Restore output to screen
        jsr     restore_output_to_screen
        
        ; Restore exit code and move to X for OSBYTE
        pla
        tax
        
        ; Set user flag with result (0 = success, non-zero = error)
        ldy     #$FF
        lda     #OSBYTE_USER_FLAG
        jsr     OSBYTE

freset_finish:
        rts
