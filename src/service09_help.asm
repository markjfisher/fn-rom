.SERVICE09_help                                 ; A=9 *HELP
{
    JSR     RememberAXY
    LDA     #ASC("F")
    JSR     OSWRCH
    LDA     #ASC("N")
    JSR     OSWRCH
    JMP     OSNEWL
}
