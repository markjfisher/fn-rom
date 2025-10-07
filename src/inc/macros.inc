; macros.inc
;

.macro dbg_string_axy arg1

.ifdef FN_DEBUG
        jsr     print_string
        .byte   arg1
        nop
        jsr     print_axy
.endif

.endmacro
