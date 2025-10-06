        .export fscv5_starCAT

        .import fuji_read_catalog
        .import print_axy
        .import print_catalog
        .import print_string

        .include "fujinet.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV5_STARCAT - Handle *CAT command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv5_starCAT:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FSCV5_STARCAT called", $0D
        nop
        jsr     print_axy
.endif
        
        ; Load and print catalog from implementation
        jsr     fuji_read_catalog
        jsr     print_catalog
        rts
