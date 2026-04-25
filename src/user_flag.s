        .export exit_user_ok
        .export set_user_flag_x

        .include "fujinet.inc"

; OSBYTE constants
OSBYTE_USER_FLAG        = $01   ; Set user flag


exit_user_ok:
        ldx     #$00

; Input: X = result code
; Uses X as the result value
set_user_flag_x:
        ; Set user flag with result (0 = success, non-zero = error)
        ldy     #$FF
        lda     #OSBYTE_USER_FLAG
        jmp     OSBYTE
