; FujiNet serial-only support code.
; Shared FujiBus-backed data operations live in fuji_data_fujibus.s; this file
; contains only serial-specific helpers and error handling.

; Only compile this file if SERIAL interface is selected
.ifdef FUJINET_INTERFACE_SERIAL

        .export err_bad_response

        .import err_bad
        .import restore_output_to_screen

        .include "fujinet.inc"

        .segment "CODE"

err_bad_response:
        jsr     restore_output_to_screen
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "response", 0


.endif  ; FUJINET_INTERFACE_SERIAL
