; Serial raw-link write implementation for FujiBus.
; Shared SLIP framing lives in fuji_link_slip.s.

        .export  fuji_link_write_byte

        .import OSWRCH

        .include "fujinet.inc"

        .segment "CODE"

fuji_link_write_byte:
        jmp     OSWRCH
