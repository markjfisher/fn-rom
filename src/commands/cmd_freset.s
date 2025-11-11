; *FRESET command implementation
; Sends a reset command frame to the FujiNet device via serial
; Frame format: [device_byte, cmd1, cmd2, cmd3, cmd4, cmd5, checksum]
; Reset frame: 70 FF 00 00 00 00 [checksum]
; Response: 'A' (ACK), 'C' (Complete)

        .export cmd_fs_freset

        .include "fujinet.inc"

        .segment "CODE"

; Import serial utilities
        ; .import _read_serial_data
        ; .import calc_checksum
        ; .import restore_output_to_screen
        .import fuji_reset
        .import set_user_flag_x
        ; .import setup_serial_19200

; Error codes
; ERR_BAD_COUNT           = $01   ; Didn't get correct read count
; ERR_TIMEOUT             = $02   ; Timeout waiting for response
; ERR_INVALID_ACK         = $03   ; Did not receive 'A' (ACK)
; ERR_INVALID_COMPLETE    = $04   ; Did not receive 'C' (Complete)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_freset - Handle *FRESET command
; Sends reset command frame to FujiNet device
; Uses cws_tmp1-6 for packet buffer (7 bytes total)
; Uses aws_tmpXX as scratch for communication
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_freset:
        jsr     fuji_reset

        ; set operation successfully (0 in user flag)
        ldx     #$00
        jmp     set_user_flag_x


        ; THE FOLLOWING IS A LOT OF ROM CODE TO JUST CHECK RESPONSE
        ; WHICH WE DON'T REALLY CARE ABOUT.

; freset_send_complete:
;         lda     #10
;         jsr     osbyte_13_delay_a

;         lda     #$02
;         sta     aws_tmp02
;         lda     #$00
;         sta     aws_tmp03
;         jsr     _drain_data

;         jsr     restore_output_to_screen

;         rts


;; ACTUALLY READ THE DATA... very long
;         ; Read response - expect 'A' (ACK) and 'C' (Complete)
;         ; Use read_serial_data to read 2 bytes into aws_tmp13/14

;         ; Set up buffer pointer from aws_tmp12/13 to aws_tmp00/01
;         lda     #<aws_tmp12
;         sta     aws_tmp00       ; Buffer pointer low
;         lda     #>aws_tmp13
;         sta     aws_tmp01       ; Buffer pointer high

;         ; Call read_serial_data - must set aws_tmp02/03 (length) before calling
;         ; C function takes NO parameters - all inputs via ZP variables
;         lda     #2              ; Read 2 bytes
;         sta     aws_tmp02       ; Length low
;         lda     #0
;         sta     aws_tmp03       ; Length high
;         jsr     _read_serial_data

;         ; On return, success status in A, 1 = ok, 0 = error, but BEQ/BNE will work without cmp
;         ; and aws_tmp04/05 contain the read count.
;         ; cmp     #$01
;         beq     freset_bad_count
; freset_read_ack:
;         ; Check if we got 2 bytes (returned in pws_tmp04/05)
;         lda     aws_tmp04       ; bytes_received low
;         cmp     #2
;         bne     freset_timeout  ; Didn't get 2 bytes = timeout
;         lda     aws_tmp05       ; bytes_received high
;         bne     freset_timeout  ; High byte should be 0

;         ; Check for 'A' (ACK)
;         lda     aws_tmp12       ; First byte
;         cmp     #'A'
;         bne     freset_invalid_ack

; freset_read_complete:
;         ; Check for 'C' (Complete)
;         lda     aws_tmp13       ; Second byte
;         cmp     #'C'
;         bne     freset_invalid_complete

;         ; Success! Set exit code to 0
;         lda     #0
;         beq     freset_exit

; freset_bad_count:
;         lda     #ERR_BAD_COUNT
;         bne     freset_exit

; freset_timeout:
;         lda     #ERR_TIMEOUT
;         bne     freset_exit

; freset_invalid_ack:
;         lda     #ERR_INVALID_ACK
;         bne     freset_exit

; freset_invalid_complete:
;         lda     #ERR_INVALID_COMPLETE
;         ; Fall through to freset_exit

; freset_exit:
;         ; Save exit code on stack (A will be trashed by restore_output_to_screen)
;         pha

;         ; Restore output to screen
;         jsr     restore_output_to_screen

;         ; Restore exit code and move to X for OSBYTE
;         pla
;         tax

        ; ldx     #$00
        ; jmp     set_user_flag_x
