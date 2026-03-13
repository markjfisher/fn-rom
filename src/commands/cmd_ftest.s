        .export  cmd_ftest

        .import  print_hex
        .import  print_string
        .import  print_newline

        .include "fujinet.inc"

USER_FLAG_VALUE := $0281

cmd_ftest:
        jsr     print_string
        .byte   "Debug FTEST command", $0d, $0d
        nop

        jsr     print_string
        .byte   "User flag: "
        nop

        lda     USER_FLAG_VALUE
        jsr     print_hex

        jsr     print_newline

        rts