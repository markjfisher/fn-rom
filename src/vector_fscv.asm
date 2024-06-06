; File System Control Vector
;
; See https://beebwiki.mdfs.net/FSCV for the various parameters this is called with.
; If A is untouched, then function is not supported.
;
; Example calls I've seen
; *FIN, first call here with A=08, Y=00, X=07. OSCLI about to do Unrec Star Command and parse 0700 for the command
; *FOO not handled, see A=03, X=01, Y=07 (OSCLI unrecognised, starting at 0701 which was the FIN string)

; We are told so we can potentially react to the event.

.FSCV_ENTRY
{
    CMP     #&0C
    BCS     filev_unknownop
    STX     &B5                ; Save X
IF _DEBUG
    JSR     PrintString
    EQUB    "FSCV "
    NOP
    JSR     PrintAXY
ENDIF
    TAX

    ; This will handle all the FSCV call backs from the OS, including A=03 => fscv3_unreccommand, which will search for our command

    LDA     fscv_table2,X
    PHA
    LDA     fscv_table1,X
    PHA
    TXA
    LDX     &B5                ; Restore X
    RTS

}

.filev_unknownop
    LDA #&00
    RTS
