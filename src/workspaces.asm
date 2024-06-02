; Copy valuable data from static workspace (sws) to
; private workspace (pws)
; (sws data 10C0-10EF, and 1100-11BF)
IF NOT(_SWRAM_)
.SaveStaticToPrivateWorkspace
{
    JSR     RememberAXY
IF _DEBUG
    JSR     PrintString
    EQUB     "Saving workspace", 13
ENDIF

    LDA     &B0
    PHA
    LDA     &B1
    PHA

    JSR     SetPrivateWorkspacePointerB0
    LDY     #&00
.stat_loop1
    CPY     #&C0
    BCC     stat_Y_lessC0
    LDA     MA+&1000,Y
    BCS     stat_Y_gtreqC0
.stat_Y_lessC0
    LDA     MA+&1100,Y
.stat_Y_gtreqC0
    STA     (&B0),Y
    INY

    CPY     #&F0

    BNE     stat_loop1

    PLA                                 ; Restore previous values
    STA     &B1
    PLA
    STA     &B0
    RTS
}
ENDIF

IF NOT(_SWRAM_)
.ClaimStaticWorkspace
    LDX     #&0A
    JSR     osbyte8F_servreq            ; Issue service request &A
    JSR     SetPrivateWorkspacePointerB0
    LDY     #<ForceReset
    LDA     #&FF
    STA     (&B0),Y                     ; Data valid in SWS
    STA     ForceReset
    INY
    STA     (&B0),Y                     ; Set pws is "empty"
    RTS

.SetPrivateWorkspacePointerB0
    PHA                                 ; Set word &B0 to
    LDA     #&00
    STA     &B0
    LDX     PagedRomSelector_RAMCopy    ; point to Private Workspace
    LDA     PagedROM_PrivWorkspaces,X
IF NOT(_MASTER_)
    AND     #&3F                        ; bits 7 & 6 are used as flags
ENDIF
    STA     &B1
    PLA
    RTS
ENDIF