; FujiNet ROM by Mark Fisher (fenrock)
; (c) 2024
;

IF _MASTER_
    CPU 1; 65C12
    MA=&C000-&0E00              ; Offset to Master hidden static workspace
; in the future, we may look at SWRAM versions
ELIF _SWRAM_
    MA=&B600-&0E00
    UTILSBUF=&BF                ; Utilities buffer page
ELSE
    MA=0
ENDIF
MP=HI(MA)

INCLUDE "src/version.asm"
INCLUDE "src/sysvars.asm"       ; OS constants

; ???
; DirectoryParam=&CC
; CurrentDrv=&CD
; CurrentCat=MA+&1082

; FSMessagesOnIfZero=MA+&10C6
; CMDEnabledIf1=MA+&10C7
; DEFAULT_DIR=MA+&10C9
; DEFAULT_DRIVE=MA+&10CA
; LIB_DIR=MA+&10CB
; LIB_DRIVE=MA+&10CC
; PAGE=MA+&10CF
; RAMBufferSize=MA+&10D0            ; HIMEM-PAGE
; ForceReset=MA+&10D3
; TubePresentIf0=MA+&10D6
; CardSort=MA+&10DE

; VID=MA+&10E0                    ; VID
; CHECK_CRC7=VID+&E               ; 1 byte
; DRIVE_INDEX0=VID                ; 4 bytes
; DRIVE_INDEX4=VID+4              ; 4 bytes
; MMC_SECTOR=VID+8                ; 3 bytes
; MMC_SECTOR_VALID=VID+&B         ; 1 bytes
; MMC_CIDCRC=VID+&C               ; 2 bytes

filesysno%=&75                    ; Filing System Number - was 74, is it an ID? i incremented it 1
filehndl%=&70                     ; First File Handle - 1

; Again, placehoder for future work
IF _SWRAM_ AND NOT(_BP12K_)
   guard_value=&B5FE
; Add a special marker that ZMMFS uses to identify an already installed SWMMFS
   org &B5FE
   EQUB MAGIC0
   EQUB MAGIC1
ELSE
   guard_value=&C000
ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start of ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ORG     &8000
    GUARD   guard_value

.lang_entry
    BRK
    BRK
    BRK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.service_entry
    JMP     fn_servicecalls


.rom_type
    EQUB    &82
.copyright_offset
    EQUB    LO(copyright-1)
.bin_version
    EQUB    &01
.title
    BUILD_NAME
.version
    BUILD_VERSION
.copyright
    BUILD_COPYRIGHT
.header_end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.go_fscv
    JMP     (FSCV)


; Save AXY and restore after calling subroutine exited
.RememberAXY
    PHA
    TXA
    PHA
    TYA
    PHA
    LDA #HI(rAXY_restore-1)        ; Return to rAXY_restore
    PHA
    LDA #LO(rAXY_restore-1)
    PHA

.rAXY_loop_init
{
    LDY #&05
.rAXY_loop
    TSX
    LDA &0107,X
    PHA
    DEY
    BNE rAXY_loop
    LDY #&0A
.rAXY_loop2
    LDA &0109,X
    STA &010B,X
    DEX
    DEY
    BNE rAXY_loop2
    PLA
    PLA
}

.rAXY_restore
    PLA
    TAY
    PLA
    TAX
    PLA
    RTS


; INCLUDE "src/fn_service_calls.asm"

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

; See https://www.sprow.co.uk/bbc/library/sidewrom.pdf for the reason codes to 
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


.SERVICE12_init_filesystem                      ; A=&12 Initialise filing system
    ; CPY     #filesysno%                         ; Y=ID no. (4=dfs etc.)
    ; BNE     label3
    ; JSR     RememberAXY
    ; JMP     CMD_CARD
    RTS
}

.SERVICE09_help                                 ; A=9 *HELP
{
    JSR     RememberAXY
    LDA     #ASC("F")
    JSR     OSWRCH
    LDA     #ASC("N")
    JSR     OSWRCH
    JMP     OSNEWL
}




PRINT "    code ends at",~P%," (",(guard_value - P%), "bytes free )"

SAVE &8000, &C000
