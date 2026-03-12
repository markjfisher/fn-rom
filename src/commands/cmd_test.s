        .export  cmd_test

        .import  _fujibus_slip_decode
        .import  _fujibus_slip_encode
        .import  print_hex
        .import  print_newline
        .import  pusha
        .import  pushax

        .include "fujinet.inc"

        .segment "CODE"

cmd_test:
        ; Build a deterministic test payload in RAM so the emulator can be
        ; single-stepped through the new FujiBus helpers without touching the
        ; serial path.
        lda     #$11
        sta     _fuji_tx_buffer+0
        lda     #SLIP_END
        sta     _fuji_tx_buffer+1
        lda     #SLIP_ESCAPE
        sta     _fuji_tx_buffer+2
        lda     #$22
        sta     _fuji_tx_buffer+3

        ; Test 1: SLIP encode the 4-byte buffer above.
        lda     #<_fuji_tx_buffer
        sta     aws_tmp00
        lda     #>_fuji_tx_buffer
        sta     aws_tmp01
        lda     #$04
        sta     aws_tmp02
        lda     #$00
        sta     aws_tmp03
        jsr     _fujibus_slip_encode
        sta     aws_tmp10
        stx     aws_tmp11

        ; Test 2: Immediately decode the encoded frame in-place.
        lda     #<_fuji_rx_buffer
        sta     aws_tmp00
        lda     #>_fuji_rx_buffer
        sta     aws_tmp01
        lda     aws_tmp10
        sta     aws_tmp02
        lda     aws_tmp11
        sta     aws_tmp03
        jsr     _fujibus_slip_decode


        ; Print a few key bytes/values so the debugger has visible breadcrumbs.
        lda     _fuji_tx_buffer+0
        jsr     print_hex
        lda     _fuji_tx_buffer+1
        jsr     print_hex
        lda     _fuji_tx_buffer+2
        jsr     print_hex
        lda     _fuji_tx_buffer+3
        jsr     print_hex
        lda     _fuji_tx_buffer+4
        jsr     print_hex
        lda     _fuji_tx_buffer+5
        jsr     print_hex
        lda     _fuji_tx_buffer+6
        jsr     print_hex
        lda     _fuji_tx_buffer+7
        jsr     print_hex
        lda     _fuji_tx_buffer+8
        jsr     print_hex
        lda     _fuji_tx_buffer+9
        jsr     print_hex

        jsr     print_newline

        rts
