;
; Minimal MOS GSINIT / GSREAD for commands with no OSCLI parameter block.
; Empty command line => num_params returns 0 (*FLS with no args).
;
        .export  h_gsinit_entry
        .export  h_gsread_entry

        .segment "CODE"

mock_cmdline:
        .byte   0

mock_gs_pos:
        .byte   0

h_gsinit_entry:
        lda     #$00
        sta     mock_gs_pos
        lda     mock_cmdline
        rts

h_gsread_entry:
        ldy     mock_gs_pos
        lda     mock_cmdline,y
        beq     @end
        inc     mock_gs_pos
        clc
        rts

@end:
        lda     #$00
        sec
        rts
