; Service call 08 - Unrecognised OSWORD
        .export service08_unrec_osword

        .import  print_axy
        .import  print_string

        .include "fujinet.inc"

        .segment "CODE"

service08_unrec_osword:

        dbg_string_axy "service08: "

        rts
