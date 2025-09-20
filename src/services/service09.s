; Service call 09 - Help
        .export service09_help

        .import remember_axy

        .import print_help_table

        .include "mos.inc"
        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERVICE 09 - HELP
;
; This service is used to print help for the FujiNet ROM.
; It is called when the user types *HELP, or *HELP <command>.
;
; It supports FUJI, UTILS, FUTILS and DFS commands.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service09_help:
        jsr     remember_axy       ; Preserve A, X, Y
        
        ; Check if this is just *HELP (no arguments)
        ; Y contains offset to first non-space char
        lda     (TextPointer),y         ; Get character at (TextPointer)+Y
        ldx     #cmdtab_offset_help
        cmp     #$0D                    ; CHR$(13) = carriage return
        bne     check_command           ; If not CR, check for command

        tya                             ; Y contains offset to first non-space char
        ldy     #cmdtab_help_cmds_size
        ; Just *HELP - print basic help
        jmp     print_help_table

check_command:
        ; TODO
        rts
