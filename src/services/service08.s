; Service call 08 - Unrecognised OSWORD
        .export service08_unrec_osword

        .import  print_axy
        .import  print_string

        .include "fujinet.inc"

        .segment "CODE"

service08_unrec_osword:

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: service08", $0D
        nop
        jsr     print_axy
.endif

        rts
