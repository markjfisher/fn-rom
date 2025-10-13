; macros.inc
;

.macro dbg_string_axy arg1

.ifdef FN_DEBUG
        php                     ; Preserve status flags
        jsr     print_string
        .byte   arg1
        nop
        jsr     print_axy
        plp                     ; Restore status flags
.endif

.endmacro
