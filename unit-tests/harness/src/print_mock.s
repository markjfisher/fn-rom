;
; Capture OSWRCH output for unit-test assertions.
; Buffer lives at $C800 (not in the harness binary — tests clear/load that RAM via DSL).
; Capture is enabled when mock_print_armed is non-zero (see test scripts).
;
        .export  mock_print_pos
        .export  mock_print_armed
        .export  h_oswrch_entry

        .segment "CODE"

MOCK_PRINT_BUFFER       = $C800
MOCK_PRINT_BUFFER_SIZE  = 256

mock_print_pos:
        .byte   0
mock_print_armed:
        .byte   0
mock_print_char:
        .byte   0

h_oswrch_entry:
        sta     mock_print_char
        lda     mock_print_armed
        beq     @discard
        ldx     mock_print_pos
        cpx     #MOCK_PRINT_BUFFER_SIZE - 1
        bcs     @done
        lda     mock_print_char
        sta     MOCK_PRINT_BUFFER,x
        inx
        stx     mock_print_pos
@done:
        lda     mock_print_char
        rts

@discard:
        lda     mock_print_char
        rts
