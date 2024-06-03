.CMD_DISC
IF NOT(_MASTER_)
; IF _BP12K_
;     LDA   PagedRomSelector_RAMCopy
;     AND   #&7F
;     TAX
; ELSE
    LDX     PagedRomSelector_RAMCopy    ; Are *DISC,*DISK disabled?
; ENDIF
    LDA     PagedROM_PrivWorkspaces,X
    AND     #&40
    BEQ     CMD_FUJINET
    RTS
ENDIF

; This is the initialisation of the fujinet on the bus

; A lot in here to deal with workspaces, and os vectors
; of which I have no idea yet if we need.

.CMD_FUJINET
    LDA     #&FF

.initFujiNet
{
    JSR     ReturnWithA0
    PHA
IF _DEBUG
    JSR     PrintString
    EQUB    "Starting FujiNet", 13
ENDIF
    LDA     #&06
    JSR     go_fscv                     ; new filing system

; Copy vectors/extended vectors
    LDX     #&0D                        ; copy vectors
.vectloop
    LDA     vectors_table,X
    STA     &0212,X
    DEX
    BPL     vectloop
    LDA     #&A8                        ; copy extended vectors
    JSR     osbyte_X0YFF
    STY     &B1
    STX     &B0
    LDX     #&07
    LDY     #&1B
.extendedvec_loop
    LDA     extendedvectors_table-&1B,Y
    STA     (&B0),Y
    INY
    LDA     extendedvectors_table-&1B,Y
    STA     (&B0),Y
    INY
    LDA     PagedRomSelector_RAMCopy
IF _BP12K_
    ORA     #&80
ENDIF
    STA     (&B0),Y
    INY
    DEX
    BNE     extendedvec_loop

    STY     CurrentCat              ; curdrvcat<>0
    STY     MA+&1083                ; ?
    STX     CurrentDrv              ; curdrv=0
    ; STX     MMC_STATE               ; Uninitialised

    LDX     #&0F                    ; vectors claimed!
    JSR     osbyte8F_servreq

; If soft break and pws "full" and not booting a disk
; then copy pws to sws
; else reset fs to defaults.

IF _SWRAM_
    LDA     ForceReset
    BMI     initdfs_noreset
    LDA     #&FF                    ; Now clear the force reset flag
    STA     ForceReset              ; so the reset only happens once
ELSE
    JSR     SetPrivateWorkspacePointerB0
    LDY     #<ForceReset
    LDA     (&B0),Y                 ; A=PWSP+&D3 (-ve=soft break)
    BPL     initdfs_reset           ; Branch if power up or hard break

    LDY     #&D4
    LDA     (&B0),Y                 ; A=PWSP+&D4
    BMI     initdfs_noreset         ; Branch if PWSP "empty"

    JSR     ClaimStaticWorkspace

IF _DEBUG
    JSR     PrintString
    EQUB    "Restoring workspace", 13
ENDIF
    LDY     #&00                    ; ** Restore copy of data
.copyfromPWStoSWS_loop
    LDA     (&B0),Y                 ; from private wsp
    CPY     #&C0                    ; to static wsp
    BCC     copyfromPWS1
    STA     MA+&1000,Y
    BCS     copyfromPWS2
.copyfromPWS1
    STA     MA+&1100,Y
.copyfromPWS2
    DEY
    BNE     copyfromPWStoSWS_loop

; Check VID CRC and if wrong reset filing system - TODO: needed?
    ; JSR     CalculateCRC7
    ; CMP     CHECK_CRC7
    ; BNE     setdefaults

    JMP     setdefaults

; currently this isn't run because we always set defaults

    LDA     #&A0                    ; Refresh channel block info
.setchansloop
    TAY
    PHA
    LDA     #&3F
    JSR     ChannelFlags_ClearBits  ; Clear bits 7 & 6, C=0
    PLA
    STA     MA+&111D,Y              ; Buffer sector hi?
    SBC     #&1F                    ; A=A-&1F-(1-C)=A-&20
    BNE     setchansloop
    BEQ     initdfs_noreset         ; always

; Initialise SWS (Static Workspace)

.initdfs_reset
    JSR     ClaimStaticWorkspace
ENDIF

; Set to defaults

.setdefaults
IF _DEBUG
    JSR     PrintString
    EQUB    "Set FN defaults", 13
ENDIF

{
    LDA     #'$'
    STA     DEFAULT_DIR
    STA     LIB_DIR
    LDA     #0
    STA     LIB_DRIVE
    LDY     #&00
    STY     DEFAULT_DRIVE
    STY     MA+&10C0

    DEY                             ; Y=&FF
    STY     CMDEnabledIf1
    STY     FSMessagesOnIfZero
    STY     MA+&10DD
}

    ; JSR     VIDRESET

.initdfs_noreset
    ; JSR     TUBE_CheckIfPresent     ; Tube present?

    PLA
    BNE     initdfs_exit            ; branch if not boot file

    ;; TODO: must implement this when we can, it reads the current drive's catalog.
    ;; Need to work out what that means if (say) there is no disk yet inserted/mounted.
    ;; which may simply be it does nothing.
    ; JSR     LoadCurDrvCat

    LDA     MA+&0F06                ; Get boot option
    JSR     A_rorx4
    BNE     notOPT0                 ; branch if not opt.0

.initdfs_exit
    RTS

; Assumes cmd strings all in same page!
.notOPT0
    LDY     #HI(BootOptions)        ; boot file?
    LDX     #LO(BootOptions)        ; ->L.!BOOT
    CMP     #&02
    BCC     jmpOSCLI                ; branch if opt 1
    BEQ     oscliOPT2               ; branch if opt 2
    IF HI(BootOptions+8)<>HI(BootOptions)
        LDY #HI(BootOptions+8)
    ENDIF
    LDX     #LO(BootOptions+8)      ; ->E.!BOOT
    BNE     jmpOSCLI                ; always
.oscliOPT2
    IF HI(BootOptions+10)<>HI(BootOptions)
        LDY #HI(BootOptions+10)
    ENDIF
    LDX     #LO(BootOptions+10)     ; ->!BOOT
.jmpOSCLI
    JMP     OSCLI
}



; .VIDRESET                ; Reset VID
; {
; ; TODO: Don't need to clear the last byte
;     LDY     #(CHECK_CRC7-VID)
; ENDIF
;     LDA     #0
; .loop
;     STA     DRIVE_INDEX0,Y
;     DEY
;     BPL     loop
;     LDA     #1
;     STA     CHECK_CRC7
;     RTS
; }
