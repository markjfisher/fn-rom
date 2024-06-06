.SERVICE03_autoboot             ; A=3 Autoboot
{
    ; BP12K_NEST
    JSR     RememberAXY
    STY     &B3                 ; if Y=0 then !BOOT
    LDA     #&7A                ; Keyboard scan
    JSR     OSBYTE              ; X=int.key.no
    TXA
    BMI     jmpAUTOBOOT
    CMP     #&43                ; "F" KEY (was M = 0x65, see scan codes from https://beebwiki.mdfs.net/Keyboard)
    BNE     srv3_exit           ; WARNING: this is at the end of SERVICE02 and is just an RTS, works because we put this code after SERVICE02
    LDA     #&78                ; write current keys pressed info
    JSR     OSBYTE
.jmpAUTOBOOT
    ; fall into AUTOBOOT instead of jumping, it's the only place it's called so placed below to save some bytes
    ; JMP     AUTOBOOT
}

.AUTOBOOT
    LDA     &B3                ; ?&B3=value of Y on call 3
    JSR     PrintString
    BOOT_NAME
    NOP
    JMP     initFujiNet
