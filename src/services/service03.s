; Service call 03 - Auto boot
        .export service03_autoboot

        .import  print_axy
        .import  print_string

        .include "fujinet.inc"

        .segment "CODE"

service03_autoboot:

        dbg_string_axy "service03: "

        rts
