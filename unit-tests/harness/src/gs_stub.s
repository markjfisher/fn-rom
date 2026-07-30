;
; Minimal MOS GSINIT / GSREAD for unit-test command lines.
; Command text lives in the harness's dedicated mock-data RAM, outside the
; linked test-program region.
; NUL ends the line. GSREAD returns CR with C=1 at end of line (BBC MOS style).
;
        .export  h_gsinit_entry
        .export  h_gsread_entry
        .export  mock_cmdline
        .export  mock_gs_pos
        .export  mock_gs_eol
        .export  mock_gs_space_term

        .segment "CODE"

MOCK_CMDLINE_BUF = $C900

mock_cmdline        := MOCK_CMDLINE_BUF

mock_gs_pos:
        .byte   0
mock_gs_eol:
        .byte   0
mock_gs_space_term:
        .byte   0

; GSINIT — continue scanning from the current command tail position.
; C=0 means spaces terminate the current token and should be skipped to find the
; next token. C=1 means only CR/NUL terminate.
h_gsinit_entry:
        php
        pla
        and     #$01
        sta     mock_gs_space_term
        lda     #$00
        sta     mock_gs_eol
        lda     mock_gs_space_term
        bne     @check_current

@skip_spaces:
        lda     MOCK_CMDLINE_BUF,y
        cmp     #' '
        bne     @check_current
        iny
        bne     @skip_spaces

@check_current:
        sty     mock_gs_pos
        lda     MOCK_CMDLINE_BUF,y
        beq     @empty
        clc
        rts

@empty:
        lda     #$00
        sec
        rts

; GSREAD — return next character; CR with C=1 at end of line.
h_gsread_entry:
        lda     mock_gs_eol
        bne     @end_line

        lda     MOCK_CMDLINE_BUF,y
        beq     @end_line
        cmp     #$0d
        beq     @end_line
        pha
        lda     mock_gs_space_term
        bne     @emit_char
        pla
        cmp     #' '
        beq     @end_space
        pha
@emit_char:
        pla
        iny
        sty     mock_gs_pos
        clc
        rts

@end_space:
        iny
        sty     mock_gs_pos
        sta     mock_gs_eol
        sec
        rts

@end_line:
        lda     #$01
        sta     mock_gs_eol
        lda     #$0d
        sec
        rts
