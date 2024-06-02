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
INCLUDE "src/sysvars.asm"           ; OS constants

;; Need to work out what is needed here, looks like this is FileSystem values
; DirectoryParam=&CC
CurrentDrv=&CD

; Everything with MA+xxx look like workspace variables allocated in an area we can use?
CurrentCat=MA+&1082

TubeNoTransferIf0=MA+&109E
; MMC_STATE=MA+&109F                  ; Bit 6 set if card initialised

FSMessagesOnIfZero=MA+&10C6
CMDEnabledIf1=MA+&10C7
DEFAULT_DIR=MA+&10C9
DEFAULT_DRIVE=MA+&10CA
LIB_DIR=MA+&10CB
LIB_DRIVE=MA+&10CC
; PAGE=MA+&10CF
; RAMBufferSize=MA+&10D0            ; HIMEM-PAGE
ForceReset=MA+&10D3
; TubePresentIf0=MA+&10D6
; CardSort=MA+&10DE

; VID=MA+&10E0                      ; VID
; CHECK_CRC7=VID+&E                 ; 1 byte
; DRIVE_INDEX0=VID                  ; 4 bytes
; DRIVE_INDEX4=VID+4                ; 4 bytes
; MMC_SECTOR=VID+8                  ; 3 bytes
; MMC_SECTOR_VALID=VID+&B           ; 1 bytes
; MMC_CIDCRC=VID+&C                 ; 2 bytes

filesysno%=&75                      ; Filing System Number - in MMS it was 74, is it an ID? I've incremented it 1
filehndl%=&70                       ; First File Handle - 1
