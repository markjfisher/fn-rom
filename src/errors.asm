.errDISK
    JSR     ReportErrorCB        ; Disk Error
    BRK
    EQUS    "Disc "
    BCC     ErrCONTINUE

.errBAD
    JSR     ReportErrorCB        ; Bad Error
    BRK
    EQUS    "Bad "
    BCC     ErrCONTINUE

; **** Report Error ****
; A string terminated with 0 causes JMP &100

; Check if writing channel buffer
.ReportErrorCB
    LDA     workspace% + &DD            ; Error while writing
    BNE     brk100_notbuf               ; channel buffer?
    JSR     ClearEXECSPOOLFileHandle
.brk100_notbuf
    LDA     #&FF
    STA     CurrentCat
    STA     workspace% + &DD            ; Not writing buffer

.ReportError
    LDX     #&02
    LDA     #&00            ; "BRK"
    STA     &0100
.ErrCONTINUE
    ;STA &B3            ; Save A???
    JSR     ResetLEDS
.ReportError2
    PLA                     ; Word &AE = Calling address + 1
    STA     &AE
    PLA
    STA     &AF
    ;LDA &B3            ; Restore A???
    LDY     #&00
    JSR     inc_word_AE_and_load
    STA     &0101            ; Error number
    DEX
.errstr_loop
    INX
    JSR     inc_word_AE_and_load
    STA     &0100,X
    BMI     prtstr_return2        ; Bit 7 set, return
    BNE     errstr_loop
    ;JSR     TUBE_RELEASE
    JMP     &0100