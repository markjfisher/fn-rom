.SERVICE02_claim_privworkspace        ; A=2 Claim private workspace, Y=First available page
{
IF _DEBUG
    JSR     PrintString
    EQUB    "Claiming Priv Workspace", 13
ENDIF

IF _MASTER_
    LDA     PagedROM_PrivWorkspaces,X    ; If A>=&DC Hidden ram is full so claim PWS in normal ram
    CMP     #&DC
    BCC     cont
    TYA
    STA     PagedROM_PrivWorkspaces,X
.cont
    PHY                ; A=PWS page
ELSE
    TYA
    PHA                ; Save Y=PWS Page
ENDIF

; IF _BP12K_
;     JSR     Init12K
; ENDIF

IF NOT(_SWRAM_)
    STA     &B1                ; Set (B0) as pointer to PWSP
    LDY     PagedROM_PrivWorkspaces,X
    IF NOT(_MASTER_)        ; Preserve bit 6
        TYA
        AND #&40
        ORA &B1
    ENDIF
    STA     PagedROM_PrivWorkspaces,X
    LDA     #&00
    STA     &B0
    CPY     &B1                ; Private workspace may have moved!
    BEQ     samepage            ; If same as before

    LDY     #<ForceReset
    STA     (&B0),Y            ; PWSP?&D3=0
.samepage
ENDIF

    LDA     #&FD            ; Read hard/soft BREAK
    JSR     osbyte_X0YFF        ; X=0=soft,1=power up,2=hard
    DEX

IF _SWRAM_
; IF _BP12K_
; ; Don't allow soft resets to update ForceReset; this can cause resets
; ; pending from previous power up/hard resets to be lost.
;     BMI skipOnSoftReset
;     JSR PageIn12K
; ENDIF
    STX ForceReset
; IF _BP12K_
;     JSR PageOut12K
; .skipOnSoftReset
; ENDIF
ELSE
    TXA                ; A= FF=soft,0=power up,1=hard
    LDY     #<ForceReset
    AND     (&B0),Y
    STA     (&B0),Y            ; So, PWSP?&D3 is +ve if:
    PHP                ; power up, hard reset or PSWP page has changed
    INY
    PLP
    BPL     notsoft            ; If not soft break

    LDA     (&B0),Y            ; A=PWSP?&D4
    BPL     notsoft            ; If PWSP "full"

; If soft break and pws is empty then I must have owned sws,
; so copy it to my pws.
    JSR     SaveStaticToPrivateWorkspace    ; Copy valuable data to PWSP

.notsoft
    LDA     #&00
    STA     (&B0),Y            ; PWSP?&D4=0 = PWSP "full"
ENDIF

IF _BP12K_
    LDA     PagedRomSelector_RAMCopy
    AND     #&7F
    TAX
ELSE
    LDX     PagedRomSelector_RAMCopy     ; restore X & A, Y=Y+2
ENDIF
    PLA
    TAY
    LDA     #&02

; IF _DEBUG
;     PHA
;     JSR     PrintString
;     EQUB    "Priv Before "
;     NOP
;     JSR     PrintAXY
;     PLA
; ENDIF

IF _MASTER_
    BIT     PagedROM_PrivWorkspaces,X
    BMI     srv3_exit            ; PWS in hidden ram
ENDIF

IF NOT(_SWRAM_)
    INY                 ; taken 1 or 2 pages for pwsp

    ; TODO: visit this, is this equivalent of FujiNet * commands? On MMFS this is BUILD/DUMP/LIST/TYPE, so may need more memory.
    ; IF _UTILS_
    ;     INY            ; Utilities need a page too
    ; ENDIF
ENDIF
}

; IF _DEBUG
;     PHA
;     JSR     PrintString
;     EQUB    "Priv After "
;     NOP
;     JSR     PrintAXY
;     PLA
; ENDIF

.srv3_exit
    RTS