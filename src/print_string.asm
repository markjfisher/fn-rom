; print Nibble and fall into print string
.PrintNibble_PrintString
    JSR PrintNibble

; **** Print String ****
; String terminated if bit 7 set
; Exit: AXY preserved, C=0
.PrintString
    STA     &B3                 ; Print String (bit 7 terminates)
    PLA                         ; A,X,Y preserved
    STA     &AE
    PLA
    STA     &AF
    LDA     &B3
    PHA                         ; Save A & Y
    TYA
    PHA
    LDY     #&00
.prtstr_loop
    JSR     inc_word_AE_and_load
    BMI     prtstr_return1      ; If end
    JSR     PrintChrA
    ; PrintChrA uses RememberAXY, so the final instruction is PLA
    ; which means it's safe to BPL
    BPL     prtstr_loop         ; always
.prtstr_return1
    PLA                         ; Restore A & Y
    TAY
    PLA
.prtstr_return2
    CLC
    JMP     (&00AE)             ; Return to caller

; As above sub, but can be spooled
.PrintStringSPL
{
    STA     &B3                 ; Save A
    PLA                         ; Pull calling address
    STA     &AE
    PLA
    STA     &AF
    LDA     &B3                 ; Save A & Y
    PHA
    TYA
    PHA
    LDY     #&00
.pstr_loop
    JSR     inc_word_AE_and_load
    BMI     prtstr_return1
    JSR     OSASCI
    JMP     pstr_loop
}

.PrintNibFullStop
    JSR     PrintNibble
.PrintFullStop
    LDA     #&2E
.PrintChrA
    JSR     RememberAXY         ; Print character
    PHA
    LDA     #&EC
    JSR     osbyte_X0YFF
    TXA                         ; X = chr destination
    PHA
    ORA     #&10
    JSR     osbyte03_Aoutstream ; Disable spooled output
    PLA
    TAX
    PLA
    JSR     OSASCI              ; Output chr
    JMP     osbyte03_Xoutstream ; Restore previous setting

.PrintHex
    PHA
    JSR     A_rorx4
    JSR     PrintNibble
    PLA

.PrintNibble
    JSR     NibToASC
    BNE     PrintChrA           ; always

; Print spaces, exit C=0 A preserved
.Print2SpacesSPL
    JSR     PrintSpaceSPL       ; Print 2 spaces
.PrintSpaceSPL
    PHA                         ; Print space
    LDA     #&20
    JSR     OSASCI
    PLA
    CLC
    RTS

.NibToASC
{
    AND     #&0F
    CMP     #&0A
    BCC     nibasc
    ADC     #&06
.nibasc
    ADC     #&30
    RTS
}

IF _DEBUG
.PrintAXY
    PHA
    JSR     PrintString
    EQUB    "A="
    NOP
    JSR     PrintHex
    JSR     PrintString
    EQUB    ";X="
    TXA
    JSR     PrintHex
    JSR     PrintString
    EQUB    ";Y="
    TYA
    JSR     PrintHex
    JSR     PrintString
    EQUB    13
    NOP
    PLA
    RTS
ENDIF