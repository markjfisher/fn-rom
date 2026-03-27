; ; Service call 03 - Auto boot
;         .export service03_autoboot

;         .import  print_axy
;         .import  print_string

;         .include "fujinet.inc"

;         .segment "CODE"

; service03_autoboot:
;         jsr     remember_axy
;         sty     aws_tmp03
;         lda     #$7A
;         jsr     OSBYTE
;         txa
;         bmi     jmp_autoboot
;         cmp     #'F'            ; F for FujiNet break

;         bne     svr3_exit


;         rts
