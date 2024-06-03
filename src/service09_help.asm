.SERVICE09_help
{
    JSR     RememberAXY
    LDA     (TextPointer),Y
    LDX     #cmdtab3
    CMP     #&0D
    BNE     jmpunreccmd
    TYA
    LDY     #cmdtab3size
    JMP     Prthelp_Xtable
}
