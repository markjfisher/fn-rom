; macros.inc
;

; Emit one command-table entry into a command group's paired string + address
; segments. Group membership is by *segment*, so a command is in the ROM iff its
; object module is linked — no inline .if in the tables (see ROM_ROLE_SPLIT_PLAN
; §5.3). The matcher (service09.s) walks each group's CMDSTR_<grp> segment and
; dispatches via the parallel CMDADR_<grp> segment by entry position, so string
; and address can never drift out of lockstep.
;
;   grp     - group token string, e.g. "FUJIFS" (selects CMDSTR_/CMDADR_<grp>)
;   name    - command text string, e.g. "ACCESS" (no leading F for the FUTILS group)
;   p1, p2  - parameter-table slot numbers (0 = none). Bit 7 of the emitted p1
;             byte terminates the command text for the matcher/help printer.
;   handler - command handler routine (entered via rts, hence the -1)
.macro cmd_entry grp, name, p1, p2, handler
        ; When a src/utils/ command is assembled as a standalone FN-UTLS.ssd
        ; binary (FN_UTIL_BINARY), it must not emit a ROM command-table fragment.
.ifndef FN_UTIL_BINARY
        .pushseg
        .segment .concat("CMDSTR_", grp)
        .byte   name, $80 | (p1), p2
        .segment .concat("CMDADR_", grp)
        .word   handler - 1
        .popseg
.endif
.endmacro

.macro dbg_string_axy arg1

.ifdef FN_DEBUG
        php                     ; Preserve status flags
        jsr     print_string
        .byte   arg1
        nop
        jsr     print_axy
        plp                     ; Restore status flags
.endif

.endmacro
