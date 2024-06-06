IF _MASTER_
    CPU 1                           ; 65C12
    MA          = &C000-&0E00       ; Offset to Master hidden static workspace
    guard_value = &C000
; in the future, we may look at SWRAM versions
; and BP12K for Beeb+
ELIF _SWRAM_
    MA          = &B600-&0E00
    guard_value = &B6FE
ELSE
    MA          = 0
    guard_value = &C000
ENDIF

MP                      = HI(MA)

disccataloguebuffer%    = MA + &0E00
workspace%              = MA + &1000
tempbuffer%             = MA + &1000

buf%                    = disccataloguebuffer%
cat%                    = disccataloguebuffer%
FilesX8                 = disccataloguebuffer%+&105


INCLUDE "src/version.asm"
INCLUDE "src/sysvars.asm"           ; OS constants

;; Need to work out what is needed here, looks like this is FileSystem values
DirectoryParam          = &CC
CurrentDrv              = &CD

CurrentCat              = workspace% + &82

TubeNoTransferIf0       = workspace% + &AE
FNBUS_STATE             = workspace% + &AF                  ; Bit 6 set if fujinet_bus initialised

;Zero Page allocations
; A8 - AF temporay * commands
; B0 - BF FileSystem temporay workspace
; C0 - CF current File system workspace

FSMessagesOnIfZero      = workspace% + &C6
CMDEnabledIf1           = workspace% + &C7
DEFAULT_DIR             = workspace% + &C9
DEFAULT_DRIVE           = workspace% + &CA
LIB_DIR                 = workspace% + &CB
LIB_DRIVE               = workspace% + &CC
PAGE                    = workspace% + &CF
RAMBufferSize           = workspace% + &D0            ; HIMEM-PAGE
ForceReset              = workspace% + &D3
TubePresentIf0          = workspace% + &D6
CardSort                = workspace% + &DE

; what are these?
; VID                 = workspace% + &E0
; VID2                = VID               ; 14 bytes
; MMC_CIDCRC          = VID2 + &E         ; 2 bytes
; CHECK_CRC7          = VID2 + &10        ; 1 byte

; All our versions set this to true currently, so will need to test what not having this value does
IF _DFS_EMUL
    filesysno%          = &04                  ; Filing System Number
    filehndl%           = &10                  ; First File Handle - 1
ELSE
    filesysno%          = &75                  ; Filing System Number - in MMS it was 74, is it an ID? I've incremented it 1
    filehndl%           = &70                  ; First File Handle - 1 ???
ENDIF

; TODO: is this important for FujiNet usage with Tube?
; See Tube Application Note No.004 Page 7 (https://mdfs.net/Info/Comp/Acorn/AppNotes/004.pdf)
; TODO: 0A is used by MMFS, I'm using 0B as the table on P28 of above has 0xA to 0xE free
tubeid%                 = &0B
