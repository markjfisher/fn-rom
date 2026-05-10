        .export fscv_entry

        .include    "harness.inc"

fscv_entry:
        lda     #$0e
        sta     paged_ram_copy
        rts
