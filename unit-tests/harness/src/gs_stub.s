;
; Minimal MOS GSINIT / GSREAD for unit-test command lines.
; Command text lives in RAM at MOCK_CMDLINE_BUF (tests use memory write #0x1E00 …).
; NUL ends the line. GSREAD returns CR with C=1 at end of line (BBC MOS style).
;
        .export  h_gsinit_entry
        .export  h_gsread_entry
        .export  mock_cmdline
        .export  mock_gs_pos
        .export  mock_gs_eol

        .segment "CODE"

MOCK_CMDLINE_BUF = $1E00

mock_cmdline        := MOCK_CMDLINE_BUF

mock_gs_pos:
        .byte   0
mock_gs_eol:
        .byte   0

; GSINIT — reset to start of line (BBC re-initialises the command tail each call).
h_gsinit_entry:
        lda     #$00
        sta     mock_gs_pos
        sta     mock_gs_eol
        ldy     #$00
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

        ldy     mock_gs_pos
        lda     MOCK_CMDLINE_BUF,y
        beq     @end_line
        cmp     #$0d
        beq     @end_line
        inc     mock_gs_pos
        clc
        rts

@end_line:
        lda     #$01
        sta     mock_gs_eol
        lda     #$0d
        sec
        rts
