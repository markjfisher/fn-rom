; os.inc
;
; imports for the os constants

.ifndef MOS_INC
OS_INC = 1

        .import  GSINIT
        .import  GSREAD
        .import  OSARGS
        .import  OSASCI
        .import  OSBGET
        .import  OSBPUT
        .import  OSBYTE
        .import  OSCLI
        .import  OSFILE
        .import  OSFIND
        .import  OSGBPB
        .import  OSNEWL
        .import  OSRDCH
        .import  OSRDRM
        .import  OSWORD
        .import  OSWRCH

        .import  CardSort
        .import  CHECK_CRC7
        .import  CMDEnabledIf1
        .import  CurrentCat
        .import  DEFAULT_DIR
        .import  DEFAULT_DRIVE
        .import  FilenameBuffer
        .import  FilesX8
        .import  ForceReset
        .import  FSCV
        .import  FSMessagesOnIfZero
        .import  LIB_DIR
        .import  LIB_DRIVE
        .import  MMC_CIDCRC
        .import  MMC_STATE
        .import  OWCtlBlock
        .import  PAGE
        .import  PagedROM_PrivWorkspaces
        .import  RAMBufferSize
        .import  TubeNoTransferIf0
        .import  TubePresentIf0
        .import  VID
        .import  VID2
        .import  Wild_Hash
        .import  Wild_Star

        .importzp  aws_tmp00
        .importzp  aws_tmp01
        .importzp  aws_tmp02
        .importzp  aws_tmp03
        .importzp  aws_tmp04
        .importzp  aws_tmp05
        .importzp  aws_tmp06
        .importzp  aws_tmp07
        .importzp  aws_tmp08
        .importzp  aws_tmp09
        .importzp  aws_tmp10
        .importzp  aws_tmp11
        .importzp  aws_tmp12
        .importzp  aws_tmp13
        .importzp  aws_tmp14
        .importzp  aws_tmp15
        .importzp  cws_tmp1
        .importzp  cws_tmp2
        .importzp  cws_tmp3
        .importzp  cws_tmp4
        .importzp  cws_tmp5
        .importzp  cws_tmp6
        .importzp  cws_tmp7
        .importzp  cws_tmp8
        .importzp  pws_tmp00
        .importzp  pws_tmp01
        .importzp  pws_tmp02
        .importzp  pws_tmp03
        .importzp  pws_tmp04
        .importzp  pws_tmp05
        .importzp  pws_tmp06
        .importzp  pws_tmp07
        .importzp  pws_tmp08
        .importzp  pws_tmp09
        .importzp  pws_tmp10
        .importzp  pws_tmp11
        .importzp  pws_tmp12
        .importzp  pws_tmp13
        .importzp  pws_tmp14
        .importzp  pws_tmp15

        .importzp  CurrentDrv
        .importzp  DirectoryParam
        .importzp  PagedRomSelector_RAMCopy
        .importzp  TextPointer

.endif
