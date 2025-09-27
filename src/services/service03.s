; Service call 03 - Auto boot
        .export service03_autoboot

        .import  print_axy
        .import  print_string

        .include "fujinet.inc"

        .segment "CODE"

service03_autoboot:

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: service03", $0D
        nop
        jsr     print_axy
.endif

        rts
