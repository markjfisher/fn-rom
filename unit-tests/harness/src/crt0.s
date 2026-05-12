        .export     halt
        .export     init_harness
        .export     end_init_harness

        .import     h_fscv_entry

        .include    "fnrom.inc"

ROM_SLOT := $0E

; this is the beginning of the app, if anything directly calls it, we halt
.segment "STARTUP"
halt:
        .byte   $db         ; STP in 65c02 emulator

.segment "CODE"
init_harness:
        ; use ROM E
        lda     #ROM_SLOT
        sta     paged_ram_copy

        ; setup FSCV
        lda     #<h_fscv_entry
        sta     $021E
        lda     #>h_fscv_entry
        sta     $021F

        ; setup abs workspace claim.
        ; We assume rom is in slot E always, and the ROM claims ABS up to page 17
        lda     #$17
        sta     paged_rom_priv_ws + ROM_SLOT

        ; call init_fuji as though ROM was built
        jsr     init_fuji
end_init_harness:
        brk


; if "init" is called in soft65c02_tester, call halt and stop the emulator
.segment "V_RESET"
        .word halt
