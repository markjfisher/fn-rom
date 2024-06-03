; various utility/helper functions

.go_fscv
    JMP     (FSCV)

.osbyte0F_flushinbuf2
    JSR     RememberAXY

.osbyte0F_flushinbuf
    LDA     #&0F
    LDX     #&01
    LDY     #&00
    BEQ     goOSBYTE            ; always

.osbyte03_Aoutstream
    TAX

.osbyte03_Xoutstream
    LDA     #&03
    BNE     goOSBYTE            ; always

.osbyte7E_ackESCAPE2
    JSR     RememberAXY

.osbyte7E_ackESCAPE
    LDA     #&7E
    BNE     goOSBYTE

.osbyte8F_servreq
    LDA     #&8F
    BNE     goOSBYTE

.osbyte_X0YFF
    LDX     #&00

.osbyte_YFF
    LDY     #&FF

.goOSBYTE
    JMP     OSBYTE

.A_rorx6and3
    LSR     A
    LSR     A
.A_rorx4and3
    LSR     A
    LSR     A
.A_rorx2and3
    LSR     A
    LSR     A
    AND     #&03
    RTS

.A_rorx5
    LSR     A
.A_rorx4
    LSR     A
.A_rorx3
    LSR     A
    LSR     A
    LSR     A
    RTS

.A_rolx5
    ASL     A
.A_rolx4
    ASL     A
    ASL     A
    ASL     A
    ASL     A
.getcat_exit
    RTS

.inc_word_AE_and_load
{
    INC     &AE
    BNE     inc_word_AE_exit
    INC     &AF
.inc_word_AE_exit
    LDA     (&AE),Y
    RTS
}

.CopyVarsB0BA
{
    JSR     CopyWordB0BA
    DEX
    DEX                 ;restore X to entry value
    JSR     cpybyte1            ;copy word (b0)+y to 1072+x
.cpybyte1
    LDA     (&B0),Y
    STA     MA+&1072,X
    INX
    INY
    RTS
}

.CopyWordB0BA
{
    JSR     cpybyte2            ;Note: to BC,X in 0.90
.cpybyte2
    LDA     (&B0),Y
    STA     &BA,X
    INX
    INY
    RTS
}

; .read_fspTextPointer
;     JSR     Set_CurDirDrv_ToDefaults    ; **Read filename to &1000
;     JMP     rdafsp_entry        ; **1st pad &1000-&103F with spaces
; .read_fspBA_reset
;     JSR     Set_CurDirDrv_ToDefaults    ; Reset cur dir & drive
; .read_fspBA
;     LDA     &BA                ; **Also creates copy at &C5
;     STA     TextPointer
;     LDA     &BB
;     STA     TextPointer+1
;     LDY     #&00
;     JSR     GSINIT_A
; .rdafsp_entry
;     LDX     #&20            ; Get drive & dir (X="space")
;     JSR     GSREAD_A            ; get C
;     BCS     errBadName            ; IF end of string
;     STA     MA+&1000
;     CMP     #&2E            ; C="."?
;     BNE     rdafsp_notdot        ; ignore leading ...'s
; .rdafsp_setdrv
;     STX     DirectoryParam        ; Save directory (X)
;     BEQ     rdafsp_entry        ; always
; .rdafsp_notdot
;     CMP     #&3A            ; C=":"? (Drive number follows)
;     BNE     rdafsp_notcolon
;     JSR     Param_DriveNo_BadDrive    ; Get drive no.
;     JSR     GSREAD_A
;     BCS     errBadName            ; IF end of string
;     CMP     #&2E            ; C="."?
;     BEQ     rdafsp_entry        ; err if not eg ":0."

.errBadName
    JSR     errBAD
    EQUB    &CC
    EQUS    "name",0

; .rdafsp_notcolon
; {
;     TAX                 ; X=last Chr
;     JSR     GSREAD_A            ; get C
;     BCS     Rdafsp_padall        ; IF end of string
;     CMP     #&2E            ; C="."?
;     BEQ     rdafsp_setdrv
;     LDX     #&01            ; Read rest of filename
; .rdafsp_rdfnloop
;     STA     MA+&1000,X
;     INX
;     JSR     GSREAD_A
;     BCS     rdafsp_padX            ; IF end of string
;     CPX     #&07
;     BNE     rdafsp_rdfnloop
;     BEQ     errBadName
; }

.GSREAD_A
{
    JSR     GSREAD            ; GSREAD ctrl chars cause error
    PHP                 ; C set if end of string reached
    AND     #&7F
    CMP     #&0D            ; Return?
    BEQ     dogsrd_exit
    CMP     #&20            ; Control character? (I.e. <&20)
    BCC     errBadName
    CMP     #&7F            ; Backspace?
    BEQ     errBadName
.dogsrd_exit
    PLP
    RTS
}

.SetTextPointerYX
    STX     TextPointer
    STY     TextPointer+1
    LDY     #&00
    RTS

.GSINIT_A
    CLC
    JMP     GSINIT

.Rdafsp_padall
    LDX     #&01            ; Pad all with spaces
.rdafsp_padX
{
    LDA     #&20            ; Pad with spaces
.rdafsp_padloop
    STA     MA+&1000,X
    INX
    CPX     #&40            ; Why &40? : Wildcards buffer!
    BNE     rdafsp_padloop
    LDX     #&06            ; Copy from &1000 to &C5
.rdafsp_cpyfnloop
    LDA     MA+&1000,X            ; 7 byte filename
    STA     &C5,X
    DEX
    BPL     rdafsp_cpyfnloop
    RTS
}

.prt_filename_Yoffset
{
    JSR     RememberAXY
    LDA     MA+&0E0F,Y
    PHP
    AND     #&7F            ; directory
    BNE     prt_filename_prtchr
    JSR     Print2SpacesSPL        ; if no dir. print "  "
    BEQ     prt_filename_nodir        ; always?
.prt_filename_prtchr
    JSR     PrintChrA            ; print dir
    JSR     PrintFullStop        ; print "."
.prt_filename_nodir
    LDX     #&06            ; print filename
.prt_filename_loop
    LDA     MA+&0E08,Y
    AND     #&7F
    JSR     PrintChrA
    INY
    DEX
    BPL     prt_filename_loop
    JSR     Print2SpacesSPL        ; print "  "
    LDA     #&20            ; " "
    PLP
    BPL     prt_filename_notlocked
    LDA     #&4C            ; "L"
.prt_filename_notlocked
    JSR     PrintChrA            ; print "L" or " "
    LDY     #&01
}

.prt_Yspaces
    JSR     PrintSpaceSPL
    DEY
    BNE     prt_Yspaces
    RTS


.conv_Yhndl_intch_exYintch
    PHA                     ; &10 to &17 are valid
    TYA
.conv_hndl_X_entry
{
    CMP     #filehndl%             ; 10
    BCC     conv_hndl10
    CMP     #filehndl%+8        ; 18
    BCC     conv_hndl18
.conv_hndl10
    LDA     #&08            ; exit with C=1,A=0    ;intch=0
.conv_hndl18
    JSR     A_rolx5            ; if Y<&10 or >&18
    TAY                     ; ch0=&00, ch1=&20, ch2=&40
    PLA                     ; ch3=&60...ch7=&E0
    RTS                     ; c=1 if not valid
}

.ClearEXECSPOOLFileHandle
{
    LDA     #&C6
    JSR     osbyte_X0YFF        ; X = *EXEC file handle
    TXA
    BEQ     ClearSpoolhandle        ; branch if no handle allocated
    JSR     ConvertXhndl_exYintch
    BNE     ClearSpoolhandle        ; If Y<>?10C2
    LDA     #&C6            ; Clear *EXEC file handle
    BNE     osbyte_X0Y0

.ClearSpoolhandle
    LDA     #&C7            ; X = *SPOOL handle
    JSR     osbyte_X0YFF
    JSR     ConvertXhndl_exYintch
    BNE     clrsplhndl_exit        ; If Y<>?10C2
    LDA     #&C7            ; Clear *SPOOL file handle
.osbyte_X0Y0
    LDX     #&00
    LDY     #&00
    JMP     OSBYTE

.ConvertXhndl_exYintch
    TXA
    TAY
    JSR     conv_Yhndl_intch_exYintch
    CPY     MA+&10C2            ; Owner?
.clrsplhndl_exit
    RTS
}

; Illuminate Caps Lock & Shift Lock
.SetLEDS
IF _ELECTRON_
    LDA     &282
    EOR     #&80
    STA     &282
    STA     &FE07
ELSE
    LDX     #&6
    STX     &FE40
    INX
    STX     &FE40
ENDIF
    RTS

; Reset LEDs
.ResetLEDS
    JSR     RememberAXY
    LDA     #&76
    JMP     OSBYTE

.IsAlphaChar
{
    PHA
    AND     #&5F            ; Uppercase
    CMP     #&41
    BCC     isalpha1            ; If <"A"
    CMP     #&5B
    BCC     isalpha2            ; If <="Z"
.isalpha1
    SEC
.isalpha2
    PLA
    RTS
}