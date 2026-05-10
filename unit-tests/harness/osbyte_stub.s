;
; Minimal test harness MOS: OSBYTE entry compatible with BBC JSR/JMP $FFF4.
;
; Optional: force CTRL for &76 tests
;   memory write $osbyte76_fake_keyboard 0x80
;
        .export  osbyte76_fake_keyboard
        .export  osbyte_entry
        .export  osbyte8f_claim_type
        .export  osbyte_break_type


        .segment "CODE"

osbyte76_fake_keyboard:
        .byte   0               ; bit7 = CTRL for OSBYTE &76

osbyte8f_claim_type:
        .byte   0               ; capture the claimed type for testing


osbyte_break_type:
        .byte   1               ; set to 0 for soft, 1 for power up, 2 for hard

; this will need to be converted to a table. far too many to do
osbyte_entry:
        cmp     #$76
        beq     osbyte_76
        cmp     #$A8
        beq     osbyte_a8
        cmp     #$8F
        beq     osbyte_8f
        cmp     #$EA
        beq     osbyte_ea
        cmp     #$FD
        beq     osbyte_fd

        ; Default: unknown OSBYTE - stop the emulator so we can inspect the command that needs implementing
        brk

; AUG: A preserved, X bit7 set if CTRL pressed, Y undefined
osbyte_76:
        pha
        lda     osbyte76_fake_keyboard
        and     #$80
        tax                     ; X = $00 or $80
        iny                     ; amend Y so it isn't the same as entry to fake it being "undefined"
        pla                     ; restore A
        rts

; AUG: A preserved, C undefined. X = $9F, Y = $0D for OS 1.2 ($0D9F)
; uses the "NEW VALUE = (OLD VALUE AND Y) EOR X", so X00YFF just reads.
; just going to return D9F
osbyte_a8:
        ldx     #$9F
        ldy     #$0D
        rts

; Issue paged ROM service request
; Entry: X=service type, Y=argument for service.
; fn-rom uses 0F = vectors claimed, and 0A = static workspace claimed
; On exit: Y may contain return arg (if appropriate)
;          X=0 if a paged ROM claimed the service request
;          A is preserved, C is undefined
osbyte_8f:
        stx     osbyte8f_claim_type

        ; invert C so it's never the same as it starts as, just to create some undefined behaviour
        bcc     do_sec_8f
        clc
        bcc     after_swap_c
do_sec_8f:
        sec
after_swap_c:
        ; This jumps into the handle_service function of the ROM ($8003) with
        ; A = claim type (e.g. 0F, 0A), X = ROM (0e), Y is untouched in entire run
        txa
        ldx     #$0E            ; TODO: make this configurable? It's the ROM number
        jmp     $8003

; tube check
osbyte_ea:
        ; return 00 in X to say no tube
        ldx     #$00
        rts

; read hard/soft break, return the value in osbyte_break_type, so test can set the kind of break
; defaults to power on
osbyte_fd:
        ldx     osbyte_break_type
        rts
