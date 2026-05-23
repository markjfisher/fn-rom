; Service call 08 - Unrecognised OSWORD
        .export service08_unrec_osword

        .import fnnet_dispatch

        .include "fujinet.inc"

        .segment "CODE"

service08_unrec_osword:
        cmp     #FNNET_OSWORD
        bne     @not_fnnet
        jmp     fnnet_dispatch
@not_fnnet:
        rts
