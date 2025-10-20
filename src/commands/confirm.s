; Confirmation prompt helper functions
; Translated from MMFS (lines 5781-5851)

        .export is_enabled_or_go
        .export go_yn
        .export confirm_yn_colon

        .import osbyte_0f_flush_inbuf2
        .import print_char
        .import print_newline
        .import print_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; is_enabled_or_go - Check if enabled flag is set, or prompt for confirmation
; If not enabled, prompts "Go (Y/N) ?"
; If user says N, returns to calling routine's caller (pops 2 bytes from stack)
; Translated from MMFS IsEnabledOrGo (lines 5781-5792)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is_enabled_or_go:
        bit     fuji_cmd_enabled
        bpl     @confirmed
        jsr     go_yn
        beq     @confirmed
        ; User said no, pop return address and return to caller's caller
        pla
        pla
@confirmed:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; confirm_yn_colon - Print " : " and fall through to confirm_yn
; Translated from MMFS ConfirmYNcolon (lines 5824-5827)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

confirm_yn_colon:
        jsr     print_string
        .byte   " : "
        bcc     confirm_yn

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; go_yn - Print "Go (Y/N) ?" and get Y/N response
; Translated from MMFS GoYN (lines 5829-5832)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

go_yn:
        jsr     print_string
        .byte   "Go (Y/N) ? "
        nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; confirm_yn - Get Y/N confirmation
; Entry: None
; Exit: Z flag set if Y, clear if N
;       A = 'Y' or 'N'
; Translated from MMFS ConfirmYN (lines 5834-5851)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

confirm_yn:
        jsr     osbyte_0f_flush_inbuf2  ; Flush input buffer
        jsr     OSRDCH                  ; Get character
        bcs     err_escape              ; If ESCAPE
        and     #$5F                    ; Convert to uppercase
        cmp     #'Y'                    ; "Y"?
        php                             ; Save flags
        beq     @conf_yn
        lda     #'N'                    ; "N"
@conf_yn:
        jsr     print_char              ; Echo character
        jsr     print_newline
        plp                             ; Restore flags (Z set if Y)
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; report_escape - Report escape condition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

err_escape:
report_escape:
        lda     #$7e
        jsr     OSBYTE
        jsr     report_error
        .byte   $11                     ; Escape error
        .byte   "Escape", 0
