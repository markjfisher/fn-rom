        .export     halt
        .export     init_harness
        .export     end_init_harness

        .import     h_fscv_entry

        .include    "fnrom.inc"

; this is the beginning of the app, if anything directly calls it, we halt
.segment "STARTUP"
halt:
        .byte   $db         ; STP in 65c02 emulator

.segment "CODE"
init_harness:
        ; setup FSCV
        lda     #<h_fscv_entry
        sta     $021E
        lda     #>h_fscv_entry
        sta     $021F

        ; call init_fuji as though ROM was built
        jsr     init_fuji
end_init_harness:
        brk


; if "init" is called in soft65c02_tester, call halt and stop the emulator
.segment "V_RESET"
        .word halt
