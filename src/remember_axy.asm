; Save AXY and restore after calling subroutine exited
.RememberAXY
    PHA
    TXA
    PHA
    TYA
    PHA
    LDA #HI(rAXY_restore-1)        ; Return to rAXY_restore
    PHA
    LDA #LO(rAXY_restore-1)
    PHA

.rAXY_loop_init
{
    LDY #&05
.rAXY_loop
    TSX
    LDA &0107,X
    PHA
    DEY
    BNE rAXY_loop
    LDY #&0A
.rAXY_loop2
    LDA &0109,X
    STA &010B,X
    DEX
    DEY
    BNE rAXY_loop2
    PLA
    PLA
}

.rAXY_restore
    PLA
    TAY
    PLA
    TAX
    PLA
    RTS

.ReturnWithA0
    PHA                     ; Sets the value of A
    TXA                     ; restored by RememberAXY
    PHA                     ; after returning from calling
    LDA     #&00            ; sub routine to 0
    TSX
    STA     &0109,X
    PLA
    TAX
    PLA
    RTS
