; TODO: move this to any CMD function that has a RTS
.NotCmdTable2
    RTS

; COMMAND TABLE 1
; FujiNetFS commands - typical file system commands to be implemented
; This is cut down to start with, more may be added.
.cmdtable1
    EQUB    &FF                ; Last command number (-1)

    EQUS    "CLOSE"
    EQUB    &80
    EQUS    "COPY"
    EQUB    &80+&21
    EQUS    "DELETE"
    EQUB    &80+&03
    EQUS    "DIR"              ; like "cd <dir>"
    EQUB    &80+&04
    EQUS    "DRIVE"
    EQUB    &80+&05

.info_cmd_index
    EQUS    "INFO"
    EQUB    &80+&02
    EQUS    "LIB"               ; search path functionality
    EQUB    &80+&06

    BRK
; End of table


; COMMAND TABLE 2
; UTILS commands, these are non fujinet functions that are general utilities
; Keep them in alphabetical order
.cmdtable2
IF _UTILS_ OR _ROMS_
    EQUB    (cmdaddr2-cmdaddr1)/2-1
IF _UTILS_
; BUILD/DUMP/LIST were here
ENDIF
IF _ROMS_
    EQUS    "ROMS"
    EQUB    &80+&06
ENDIF
    BRK
ENDIF

.cmdtable22
    EQUB    (cmdaddr22-cmdaddr1)/2-1
IF _DFS_EMUL
    EQUS    "DISC"
    EQUB    &80
    EQUS    "DISK"
    EQUB    &80
ENDIF
    EQUS    "FUJINET"
    EQUB    &80
    EQUS    "CARD"
    EQUB    &80
    BRK

; COMMAND TABLE 3
; HELP commands
.cmdtable3
    EQUB    (cmdaddr3-cmdaddr1)/2-1
    EQUS    "FUTILS"
    EQUB    &80
    EQUS    "FUJINET"
    EQUB    &80
IF _UTILS_ OR _ROMS_
    EQUS    "UTILS"
    EQUB    &80
ENDIF
    BRK

; COMMAND TABLE 4
; FUTILS commands, all are expected to be prefixed with "F" in code, so can skip first char here
.cmdtable4
    EQUB    (cmdaddr4-cmdaddr1)/2-1

    EQUS    "BOOT"
    EQUB    &80+&08
    EQUS    "CAT"
    EQUB    &80+&09
    EQUS    "DIR"
    EQUB    &80+&04
    EQUS    "DRIVE"
    EQUB    &80
    EQUS    "IN"
    EQUB    &80+&7A

    BRK

; Address of sub-routines
; If bit 15 clear, call MMC_BEGIN2
.cmdaddr1
    EQUW    CMD_CLOSE-1
    EQUW    CMD_COPY-1
    EQUW    CMD_DELETE-1
    EQUW    CMD_DIR-1
    EQUW    CMD_DRIVE-1
    EQUW    CMD_INFO-1
    EQUW    CMD_LIB-1
    EQUW    NotCmdTable1-1

.cmdaddr2
IF _UTILS_ OR _ROMS_
IF _UTILS_
; BUILD/DUMP/LIST were here
ENDIF
IF _ROMS_
    EQUW    CMD_ROMS-&8001
ENDIF
    EQUW    NotCmdTable2-1
ENDIF

.cmdaddr22
IF _DFS_EMUL
    EQUW    CMD_DISC-1
    EQUW    CMD_DISC-1
ENDIF
    EQUW    CMD_FUJINET-1
    EQUW    CMD_FUJINET-1
    EQUW    NotCmdTable22-1

.cmdaddr3
    EQUW    CMD_FUTILS-1
    EQUW    CMD_HELP_FUJINET-1  ; help command for fujinet
IF _UTILS_ OR _ROMS_            ; not sure if we have many utils separate to fujinet ones. time will tell
    EQUW    CMD_UTILS-1
ENDIF
    EQUW    CMD_NOTHELPTBL-1

.cmdaddr4
    EQUW    CMD_FBOOT-&8001
    EQUW    CMD_FCAT-&8001
    EQUW    CMD_FDIR-&8001
    EQUW    CMD_FDRIVE-&8001
    EQUW    CMD_FIN-&8001
    EQUW    NotCmdTable4-1         ; *RUN functionality, as the last entry it's common to just try running the arg

.cmdaddrX

cmdtab1size  = (cmdaddr2-cmdaddr1)/2-1
cmdtab2size  = (cmdaddr22-cmdaddr2)/2-1
cmdtab22size = (cmdaddr3-cmdaddr22)/2-1
cmdtab3size  = (cmdaddr4-cmdaddr3)/2-1
cmdtab4size  = (cmdaddrX-cmdaddr4)/2-1

cmdtab2      = cmdtable2-cmdtable1
cmdtab22     = cmdtable22-cmdtable1
cmdtab3      = cmdtable3-cmdtable1
cmdtab4      = cmdtable4-cmdtable1

; end of address tables

.NotCmdTable1
    LDX     #cmdtab4
    JSR     GSINIT_A
    LDA     (TextPointer),Y
    INY

    ORA     #&20
    CMP     #&66            ; "f"
    BEQ     UnrecCommandTextPointer

    DEY
    JMP     NotCmdTable4

; This is how the non 22 commands gets picked up, via FSCV unhandled vector
.fscv3_unreccommand
    JSR     SetTextPointerYX
    LDX     #&00

.UnrecCommandTextPointer
{

; IF _DEBUG
;     JSR     PrintString
;     EQUB    "UCTP "
;     NOP
;     JSR     PrintAXY
; ENDIF

    LDA     cmdtable1,X             ; Get number of last command
    STA     &BE
    TYA                             ; X=FD+3=0 ie all commands
    PHA                             ; X=start command,

.unrecloop1
    INC     &BE

    PLA                             ; contain addr/code of prev.
    PHA
    TAY                             ; restore Y
    JSR     GSINIT_A                ; TextPointer+Y = cmd line

    INX
    LDA     cmdtable1,X
    BEQ     gocmdcode               ; If end of table

    DEX
    DEY
    STX     &BF                     ; USED IF SYNTAX ERROR

.unrecloop2
    INX
    INY                             ; X=start of next string-1
    LDA     cmdtable1,X
    BMI     endofcmd_oncmdline      ; end of table entry

.unrecloop2in
    EOR     (TextPointer),Y
    AND     #&5F                    ; ignore case
    BEQ     unrecloop2              ; while chrs eq go loop2
    DEX

; didn't match, skip to the end of this command to try the next
.unrecloop3
    INX                             ; init next loop
    LDA     cmdtable1,X
    BPL     unrecloop3

    LDA     (TextPointer),Y         ; find end of table entry
    CMP     #&2E                    ; does cmd line end with (e.g. L. for LIST)
    BNE     unrecloop1              ; full stop?
    INY                             ; If no, doesn't match
    BCS     gocmdcode

.endofcmd_oncmdline
    LDA     (TextPointer),Y         ; If >="." (always)
    JSR     IsAlphaChar             ; matched table entry
    BCC     unrecloop1

.gocmdcode
    PLA                             ; if more chars.

; IF _DEBUG
;     PHA
;     JSR     PrintString
;     EQUS    "COMMAND: "
;     LDA     &BE
;     JSR     PrintHex
;     LDA     #' '
;     JSR     PrintChrA
;     PLA
;     JSR     PrintAXY
; ENDIF

    LDA     &BE
    ASL     A
    TAX
    ; This gets the last 2 bytes of CMDADDR(xx) and pushes address onto the stack for an indirect JMP via RTS
    ; which is the NotCmdTable(xx) routine address
    LDA     cmdaddr1+1,X            ; Forget Y
    BPL     dofninit
.gocmdcode2
    PHA                             ; Push sub address and
    LDA     cmdaddr1,X              ; return to it!
    PHA
    RTS

.dofninit
    JSR     FNBUS_BEGIN2
    ORA     #&80
    BNE     gocmdcode2
}
