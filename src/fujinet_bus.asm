.FNBUS_BEGIN2
    JSR     RememberAXY

IF _DEBUG
    JSR     PrintString
    EQUB    "FNBUS_BEGIN2 "
    NOP
    JSR     PrintAXY
ENDIF

    JSR     FNBUS_BEGIN1
    JMP     FNBUS_END

.FNBUS_BEGIN1
{
    LDX     #&0F

.begloop1
    LDA     &BC,X
    STA     workspace%+&90,X
    DEX
    BPL     begloop1

; Reset device
    JSR     FNBUS_DEVICE_RESET

; Check if MMC initialised
; If not intialise the card
    BIT     FNBUS_STATE
    BVC     begX
    RTS

.begX
    JSR     FNBUS_INIT
    BCS     buserr

    ; OTHER FUJINET BITS HERE, LIKE LOADING DISKS etc.

    RTS

.buserr
    JSR     ReportError
    EQUB    &FF
    EQUS    "FujiNet?",0

}

.FNBUS_DEVICE_RESET
    RTS

; Initialise FujiNet
; Carry = 0 if ok
; Carry = 1 if no device found
; TODO: implement this!
.FNBUS_INIT
    LDA     #&40
    STA     FNBUS_STATE
    JSR     ResetLEDS
    CLC
    RTS

.FNBUS_END
{
    LDX     #&0F
.eloop0
    LDA     workspace% + &90,X
    STA     &BC,X
    DEX
    BPL     eloop0
    RTS
}