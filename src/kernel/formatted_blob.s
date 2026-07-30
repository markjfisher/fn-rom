        .export cfl_print_formatted_blob

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp12
        .importzp aws_tmp13

        .import print_char
        .import print_newline

        .segment "CODE"

; Print preformatted response text at aws_tmp00..aws_tmp12:13.
; Line feeds in protocol text become BBC newlines.
cfl_print_formatted_blob:
@loop:
        lda     aws_tmp00
        cmp     aws_tmp12
        lda     aws_tmp01
        sbc     aws_tmp13
        bcs     @done

        ldy     #$00
        lda     (aws_tmp00),y
        cmp     #$0A
        beq     @newline
        jsr     print_char
        bne     @advance               ; always: print_char preserves non-zero A

@newline:
        jsr     print_newline

@advance:
        inc     aws_tmp00
        bne     @loop
        inc     aws_tmp01
        bne     @loop                  ; high byte cannot wrap for this buffer

@done:
        rts
