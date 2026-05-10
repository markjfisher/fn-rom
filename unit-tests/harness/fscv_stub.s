        .export h_fscv_entry

        .include    "harness.inc"

h_fscv_entry:
        lda     #$0e
        sta     paged_ram_copy
        rts
