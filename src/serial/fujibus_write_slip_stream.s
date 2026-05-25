; Serial raw-link write implementation for FujiBus.
; Shared SLIP framing lives in fuji_link_slip.s.

        .export  fuji_link_write_byte

        .include "fujinet.inc"

ACIA_STATUS     := $FE08
ACIA_DATA       := $FE09
ACIA_TDRE       := $02

        .segment "CODE"

fuji_link_write_byte:
        pha
@wait_tdre:
        lda     ACIA_STATUS
        and     #ACIA_TDRE
        beq     @wait_tdre
        pla
        sta     ACIA_DATA
        rts
