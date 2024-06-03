IF NOT(_MASTER_) AND NOT(_SWRAM_)
.SERVICE01_claim_absworkspace       ; A=1 Claim absolute workspace
{
IF _DEBUG
    JSR     PrintString
    EQUB    "Claiming ABS Workspace", 13
ENDIF
    CPY     #&17                    ; Y=current upper limit
    BCS     exit                    ; already >=&17
    LDY     #&17                    ; Up upper limit to &17
.exit
    RTS
}
ENDIF