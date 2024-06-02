;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The entry for the ROM services

.fn_servicecalls
{

IF _MASTER_
    BIT     PagedROM_PrivWorkspaces,X   ; ROM disabled if 01xxxxxx or 10xxxxxx
    BPL     lbl2                        ; if 0x
    BVS     lbl3                        ; if 11
.lbl1
    RTS
.lbl2
    BVS     lbl1                        ; if 01
.lbl3
; Note: 00 = PWS in normal ram, 11 = PWS in hidden ram

ELSE
    PHA
    LDA     PagedROM_PrivWorkspaces,X
    BMI     romdisabled                 ; if bit 7 set
.lbl1
    PLA
ENDIF

    CMP     #&12
    BEQ     SERVICE12_init_filesystem
    CMP     #&0B

IF _MASTER_
    BCC     label4
    CMP     #&28
    BCS     service_null
    CMP     #&21
    BCC     service_null
    SBC     #&16
ELSE
    BCS     service_null
ENDIF

.label4
    ASL     A
    TAX
    LDA     data+1,X
    PHA
    LDA     data,X
    PHA

    ; Restore A & X values
; IF _BP12K_
;     TXA
;     PHA
;     LDA     PagedRomSelector_RAMCopy
;     AND     #&7F
;     TAX
;     PLA
; ELSE
    TXA
    LDX     PagedRomSelector_RAMCopy
; ENDIF
    LSR     A
    CMP     #&0B
    BCC     label3
    ADC     #&15
.label3

.service_null
    RTS

.romdisabled
    PLA
    RTS

; See https://www.sprow.co.uk/bbc/library/sidewrom.pdf for the reason codes
;

.data
    EQUW    service_null-1                      ; 0
IF _MASTER_ OR _SWRAM_
    EQUW    service_null-1                      ; 1 Use 21 instead for MASTER
ELSE
    EQUW    service_null-1                      ; 1
ENDIF
    EQUW    service_null-1                      ; 2
    EQUW    service_null-1                      ; 3
    EQUW    service_null-1                      ; 4
    EQUW    service_null-1                      ; 5
    EQUW    service_null-1                      ; 6
    EQUW    service_null-1                      ; 7
    EQUW    service_null-1                      ; 8
    EQUW    SERVICE09_help-1                    ; 9
IF _SWRAM_
    EQUW    service_null-1                      ; A
ELSE
    EQUW    service_null-1                      ; A
ENDIF

IF _MASTER_
    EQUW    service_null-1                      ; 21
    EQUW    service_null-1                      ; 22
    EQUW    service_null-1                      ; 23
    EQUW    service_null-1                      ; 24
    EQUW    service_null-1                      ; 25
    EQUW    service_null-1                      ; 26
    EQUW    service_null-1                      ; 27
ENDIF

; This needs to reach inside the current scope, so is not separated into its own file
.SERVICE12_init_filesystem                      ; A=&12 Initialise filing system
    ; CPY     #filesysno%                       ; Y=ID no. (4=dfs etc.)
    ; BNE     label3
    ; JSR     RememberAXY
    ; JMP     CMD_CARD
    RTS
}
