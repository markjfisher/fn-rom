.SERVICE04_unrec_command            ; A=4 Unrec Command
    ; BP12K_NEST
    JSR     RememberAXY
    LDX     #cmdtab22               ; UTILS commands
.jmpunreccmd
    JMP     UnrecCommandTextPointer
.NotCmdTable22
IF NOT(_MASTER_)
    ; IF _UTILS_ OR _ROMS_
        LDX #cmdtab2
        BNE jmpunreccmd
    ; ELSE
    ;     RTS
    ; ENDIF
ELSE
    RTS
ENDIF