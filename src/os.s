; MOS + Other definitions

        .export  GSINIT
        .export  GSREAD
        .export  OSARGS
        .export  OSASCI
        .export  OSBGET
        .export  OSBPUT
        .export  OSBYTE
        .export  OSCLI
        .export  OSFILE
        .export  OSFIND
        .export  OSGBPB
        .export  OSNEWL
        .export  OSRDCH
        .export  OSRDRM
        .export  OSWORD
        .export  OSWRCH

        .export  CardSort
        .export  CHECK_CRC7
        .export  CMDEnabledIf1
        .export  CurrentCat
        .export  DEFAULT_DIR
        .export  DEFAULT_DRIVE
        .export  FilenameBuffer
        .export  FilesX8
        .export  ForceReset
        .export  FSCV
        .export  FSMessagesOnIfZero
        .export  LIB_DIR
        .export  LIB_DRIVE
        .export  MMC_CIDCRC
        .export  MMC_STATE
        .export  OWCtlBlock
        .export  PAGE
        .export  PagedROM_PrivWorkspaces
        .export  RAMBufferSize
        .export  TubeNoTransferIf0
        .export  TubePresentIf0
        .export  VID
        .export  VID2
        .export  Wild_Hash
        .export  Wild_Star

        .exportzp  aws_tmp00
        .exportzp  aws_tmp01
        .exportzp  aws_tmp02
        .exportzp  aws_tmp03
        .exportzp  aws_tmp04
        .exportzp  aws_tmp05
        .exportzp  aws_tmp06
        .exportzp  aws_tmp07
        .exportzp  aws_tmp08
        .exportzp  aws_tmp09
        .exportzp  aws_tmp10
        .exportzp  aws_tmp11
        .exportzp  aws_tmp12
        .exportzp  aws_tmp13
        .exportzp  aws_tmp14
        .exportzp  aws_tmp15
        .exportzp  cws_tmp1
        .exportzp  cws_tmp2
        .exportzp  cws_tmp3
        .exportzp  cws_tmp4
        .exportzp  cws_tmp5
        .exportzp  cws_tmp6
        .exportzp  cws_tmp7
        .exportzp  cws_tmp8
        .exportzp  pws_tmp00
        .exportzp  pws_tmp01
        .exportzp  pws_tmp02
        .exportzp  pws_tmp03
        .exportzp  pws_tmp04
        .exportzp  pws_tmp05
        .exportzp  pws_tmp06
        .exportzp  pws_tmp07
        .exportzp  pws_tmp08
        .exportzp  pws_tmp09
        .exportzp  pws_tmp10
        .exportzp  pws_tmp11
        .exportzp  pws_tmp12
        .exportzp  pws_tmp13
        .exportzp  pws_tmp14
        .exportzp  pws_tmp15

        .exportzp  CurrentDrv
        .exportzp  DirectoryParam
        .exportzp  PagedRomSelector_RAMCopy
        .exportzp  TextPointer


; OS vectors
OSRDRM      := $FFB9
GSINIT      := $FFC2
GSREAD      := $FFC5
OSFIND      := $FFCE
OSGBPB      := $FFD1
OSBPUT      := $FFD4
OSBGET      := $FFD7
OSARGS      := $FFDA
OSFILE      := $FFDD
OSRDCH      := $FFE0
OSASCI      := $FFE3
OSNEWL      := $FFE7
OSWRCH      := $FFEE
OSWORD      := $FFF1
OSBYTE      := $FFF4
OSCLI       := $FFF7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Temporary Zeropage Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Command workspace variables
cws_tmp1    := $A8
cws_tmp2    := $A9
cws_tmp3    := $AA
cws_tmp4    := $AB
cws_tmp5    := $AC
cws_tmp6    := $AD
cws_tmp7    := $AE
cws_tmp8    := $AF

; Absolute workspace variables
aws_tmp00   := $B0
aws_tmp01   := $B1
aws_tmp02   := $B2
aws_tmp03   := $B3
aws_tmp04   := $B4
aws_tmp05   := $B5
aws_tmp06   := $B6
aws_tmp07   := $B7
aws_tmp08   := $B8
aws_tmp09   := $B9
aws_tmp10   := $BA
aws_tmp11   := $BB
aws_tmp12   := $BC
aws_tmp13   := $BD
aws_tmp14   := $BE
aws_tmp15   := $BF


; Private workspace variables
pws_tmp00   := $C0
pws_tmp01   := $C1
pws_tmp02   := $C2
pws_tmp03   := $C3
pws_tmp04   := $C4
pws_tmp05   := $C5
pws_tmp06   := $C6
pws_tmp07   := $C7
pws_tmp08   := $C8
pws_tmp09   := $C9
pws_tmp10   := $CA
pws_tmp11   := $CB
pws_tmp12   := $CC
pws_tmp13   := $CD
pws_tmp14   := $CE
pws_tmp15   := $CF

TextPointer                     := $F2
PagedRomSelector_RAMCopy        := $F4
PagedROM_PrivWorkspaces         := $0DF0

FSCV                := $021E

DirectoryParam      := $CC
CurrentDrv          := $CD
CurrentCat          := $1082

TubeNoTransferIf0   := $10AE
MMC_STATE           := $10AF
OWCtlBlock          := $10B0
FSMessagesOnIfZero  := $10C6
CMDEnabledIf1       := $10C7
DEFAULT_DIR         := $10C9
DEFAULT_DRIVE       := $10CA
LIB_DIR             := $10CB
LIB_DRIVE           := $10CC
Wild_Hash           := $10CD              ; Wildcard character
Wild_Star           := $10CE              ; Wildcard character
PAGE                := $10CF
RAMBufferSize       := $10D0
ForceReset          := $10D3
TubePresentIf0      := $10D6
CardSort            := $10DE

VID                 := $10E0
VID2                := VID
MMC_CIDCRC          := VID2+$0E
CHECK_CRC7          := VID2+$10

FilesX8             := $0F05

; MMFS-compatible memory addresses
FilenameBuffer      := $1000              ; Filename buffer
