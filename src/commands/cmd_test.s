        .export  cmd_test

        .import  print_hex
        .import  print_newline

        .include "fujinet.inc"

        .segment "CODE"

cmd_test:
        lda     #'A'
        jsr     print_hex
        jsr     print_newline

        rts
