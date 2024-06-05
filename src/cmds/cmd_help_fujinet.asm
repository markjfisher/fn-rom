.CMD_HELP_FUJINET
    TYA
    LDX     #0                ; cmd table 1
    LDY     #cmdtab1size        ; no.of commands

.Prthelp_Xtable
{
    PHA
    JSR     PrintString
    EQUB    13
    SYSTEM_NAME
    EQUB    32
    STX     &BF
    STY     &B7                ; ?&B7 = command counter

    LDX     #0                ; Print ROM version number
.verloop
    LDA     version,X
    BEQ     verex
    JSR     PrintChrA
    INX
    BNE     verloop

.verex
    LDA     #13
    JSR     PrintChrA

.help_dfs_loop
    LDA     #0
    STA     &B9                ; ?&B9=0=print command (not error)
    LDY     #1
    JSR     prtcmd_Print_Y_Spaces_IfNotErr    ; print "  ";
    JSR     prtcmdAtBCadd1        ; print cmd & parameters
    JSR     PrintNewLine        ; print
    DEC     &B7
    BNE     help_dfs_loop
    PLA                ; restore Y
    TAY
}
.morehelp
    LDX     #cmdtab3            ; more? Eg *HELP DFS UTILS
    JMP     UnrecCommandTextPointer    ; start cmd @ A3 in table


.CMD_NOTHELPTBL
{
    JSR     GSINIT_A
    BEQ     initdfs_exit        ; null str. we are abusing the load order to save a byte here, be careful of reordering code
.cmd_nothelptlb_loop
    JSR     GSREAD_A
    BCC     cmd_nothelptlb_loop        ; if not end of str
    BCS     morehelp            ; always
}
