;
; Capture OSWRCH output for unit-test assertions.
;
        .export  mock_print_pos
        .export  mock_print_buffer
        .import  mock_slip_len
        .import  mock_slip_pos

        .export  h_oswrch_entry

        .segment "CODE"

MOCK_PRINT_BUFFER_SIZE  = 256

        .segment "MOCK_DATA"
mock_print_buffer:
        .res    MOCK_PRINT_BUFFER_SIZE

        .segment "CODE"
mock_print_pos:
        .byte   0

h_oswrch_entry:
        ; Ignore OSWRCH from fujibus SLIP TX until mock response fully consumed.
        ; Discard OSWRCH until mock SLIP replay has finished (see mock_slip_len).
        lda     mock_slip_pos
        cmp     mock_slip_len
        bcc     @discard
        ldx     mock_print_pos
        cpx     #MOCK_PRINT_BUFFER_SIZE - 1
        bcs     @done
        sta     mock_print_buffer,x
        inx
        stx     mock_print_pos
@done:
        rts

@discard:
        rts
