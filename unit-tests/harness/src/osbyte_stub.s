;
; Minimal test harness MOS: OSBYTE entry compatible with BBC JSR/JMP $FFF4.
;
; Optional: force CTRL for &76 tests
;   memory write $osbyte_76_fake_keyboard 0x80
;
        .export  h_osbyte_entry
        .export  h_osbyte_do_jmp
        .export  osbyte_76_fake_keyboard
        .export  osbyte_8f_claim_type
        .export  osbyte_break_type

        .export  osbyte_76
        .export  osbyte_83
        .export  osbyte_84
        .export  osbyte_8f
        .export  osbyte_a8
        .export  osbyte_ea
        .export  osbyte_fd

        .import  osbyte_80
        .import  osbyte_91

        .segment "CODE"

osbyte_noop:
        rts

osbyte_01:
        rts

; OSBYTE 236 — character destination (print_char); return screen in X.
osbyte_ec:
        ldx     #$00
        rts

osbyte_76_fake_keyboard:
        .byte   0               ; bit7 = CTRL for OSBYTE &76

osbyte_8f_claim_type:
        .byte   0               ; capture the claimed type for testing


osbyte_break_type:
        .byte   1               ; set to 0 for soft, 1 for power up, 2 for hard

osbyte_saveX:
        .byte   0               ; somewhere to stash X that isn't the stack

; Preserve MOS parameters, dispatch by A (OSBYTE number) via RTS trampoline
h_osbyte_entry:
        stx     osbyte_saveX
        tax
        lda     osbyte_table_hi,x
        pha
        lda     osbyte_table_lo,x
        pha
        ; restore A and X
        txa
        ldx     osbyte_saveX
h_osbyte_do_jmp:
        rts

; Default: unimplemented OSBYTE — replace table slot when adding a handler
osbyte_unimplemented:
        ; causes emulator to stop
        brk

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSBYTE dispatch tables (256 entries, address minus 1 for RTS trick)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osbyte_table_lo:
.repeat 256, cmd
        .if     cmd = $01
        .byte   .lobyte(osbyte_01 - 1)
        .elseif cmd = $02
        .byte   .lobyte(osbyte_noop - 1)
        .elseif cmd = $03
        .byte   .lobyte(osbyte_noop - 1)
        .elseif cmd = $07
        .byte   .lobyte(osbyte_noop - 1)
        .elseif cmd = $08
        .byte   .lobyte(osbyte_noop - 1)
        .elseif cmd = $15
        .byte   .lobyte(osbyte_noop - 1)
        .elseif cmd = $76
        .byte   .lobyte(osbyte_76 - 1)
        .elseif cmd = $83
        .byte   .lobyte(osbyte_83 - 1)
        .elseif cmd = $84
        .byte   .lobyte(osbyte_84 - 1)
        .elseif cmd = $80
        .byte   .lobyte(osbyte_80 - 1)
        .elseif cmd = $91
        .byte   .lobyte(osbyte_91 - 1)
        .elseif cmd = $a8
        .byte   .lobyte(osbyte_a8 - 1)
        .elseif cmd = $8f
        .byte   .lobyte(osbyte_8f - 1)
        .elseif cmd = $ea
        .byte   .lobyte(osbyte_ea - 1)
        .elseif cmd = $ec
        .byte   .lobyte(osbyte_ec - 1)
        .elseif cmd = $fd
        .byte   .lobyte(osbyte_fd - 1)
        .else
        .byte   .lobyte(osbyte_unimplemented - 1)
        .endif
.endrepeat

osbyte_table_hi:
.repeat 256, cmd
        .if     cmd = $01
        .byte   .hibyte(osbyte_01 - 1)
        .elseif cmd = $02
        .byte   .hibyte(osbyte_noop - 1)
        .elseif cmd = $03
        .byte   .hibyte(osbyte_noop - 1)
        .elseif cmd = $07
        .byte   .hibyte(osbyte_noop - 1)
        .elseif cmd = $08
        .byte   .hibyte(osbyte_noop - 1)
        .elseif cmd = $15
        .byte   .hibyte(osbyte_noop - 1)
        .elseif cmd = $76
        .byte   .hibyte(osbyte_76 - 1)
        .elseif cmd = $83
        .byte   .hibyte(osbyte_83 - 1)
        .elseif cmd = $84
        .byte   .hibyte(osbyte_84 - 1)
        .elseif cmd = $80
        .byte   .hibyte(osbyte_80 - 1)
        .elseif cmd = $91
        .byte   .hibyte(osbyte_91 - 1)
        .elseif cmd = $8f
        .byte   .hibyte(osbyte_8f - 1)
        .elseif cmd = $a8
        .byte   .hibyte(osbyte_a8 - 1)
        .elseif cmd = $ea
        .byte   .hibyte(osbyte_ea - 1)
        .elseif cmd = $ec
        .byte   .hibyte(osbyte_ec - 1)
        .elseif cmd = $fd
        .byte   .hibyte(osbyte_fd - 1)
        .else
        .byte   .hibyte(osbyte_unimplemented - 1)
        .endif
.endrepeat

; OSBYTE $83 — OSHWM (top of user memory); YX = address.
osbyte_83:
        ldx     #$00
        ldy     #$19
        rts

; OSBYTE $84 — HIMEM; YX = address.
osbyte_84:
        ldx     #$00
        ldy     #$80
        rts

; AUG: A preserved, X bit7 set if CTRL pressed, Y undefined
osbyte_76:
        pha
        lda     osbyte_76_fake_keyboard
        and     #$80
        tax                     ; X = $00 or $80
        iny                     ; amend Y so it isn't the same as entry to fake it being "undefined"
        pla                     ; restore A
        rts


; Issue paged ROM service request
; Entry: X=service type, Y=argument for service.
; fn-rom uses 0F = vectors claimed, and 0A = static workspace claimed
; On exit: Y may contain return arg (if appropriate)
;          X=0 if a paged ROM claimed the service request
;          A is preserved, C is undefined
osbyte_8f:
        stx     osbyte_8f_claim_type

        ; invert C so it's never the same as it starts as, just to create some undefined behaviour
        bcc     @do_sec_8f
        clc
        bcc     @after_swap_c
@do_sec_8f:
        sec
@after_swap_c:
        ; This jumps into the handle_service function of the ROM ($8003) with
        ; A = claim type (e.g. 0F, 0A), X = ROM (0e), Y is untouched in entire run
        txa
        ldx     #$0E            ; TODO: make this configurable? It's the ROM number
        jmp     $8003

; AUG: A preserved, C undefined. X = $9F, Y = $0D for OS 1.2 ($0D9F)
; uses the "NEW VALUE = (OLD VALUE AND Y) EOR X", so X00YFF just reads.
; just going to return D9F
osbyte_a8:
        ldx     #$9F
        ldy     #$0D
        rts

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
