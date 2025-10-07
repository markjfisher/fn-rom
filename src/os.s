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

        .export  CHECK_CRC7
        .export  CurrentCat
        .export  FilesX8
        .export  FSCV
        .export  MMC_CIDCRC
        .export  MMC_STATE
        .export  OWCtlBlock
        .export  paged_rom_priv_ws
        .export  VID
        .export  VID2

        .export  fuji_filename_buffer
        .export  fuji_open_channels
        .export  fuji_channel_flag_bit
        .export  fuji_intch
        .export  fuji_cat_file_offset
        .export  fuji_channel_block_size
        .export  fuji_saved_x
        .export  fuji_fs_messages_on
        .export  fuji_cmd_enabled
        .export  fuji_default_dir
        .export  fuji_default_drive
        .export  fuji_lib_dir
        .export  fuji_lib_drive
        .export  fuji_wild_hash
        .export  fuji_wild_star
        .export  fuji_page
        .export  fuji_ram_buffer_size
        .export  fuji_source_drive
        .export  fuji_dest_drive
        .export  fuji_force_reset
        .export  fuji_disk_table_index
        .export  fuji_tube_present
        .export  fuji_gbpb_table_lo
        .export  fuji_gbpb_table_hi
        .export  fuji_text_ptr_offset
        .export  fuji_text_ptr_hi
        .export  fuji_param_block_lo
        .export  fuji_param_block_hi
        .export  fuji_error_flag
        .export  fuji_card_sort

        .export  fuji_channel_flags
        .export  fuji_channel_buffer
        .export  fuji_1111
        .export  fuji_1112
        .export  fuji_1113
        .export  fuji_1114
        .export  fuji_1115
        .export  fuji_1116
        .export  fuji_1117

        .export  fuji_state
        .export  fuji_current_disk
        .export  fuji_operation_type
        .export  fuji_buffer_addr
        .export  fuji_file_offset
        .export  fuji_block_size
        .export  fuji_current_sector

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
        .exportzp  paged_ram_copy
        .exportzp  TextPointer


; OS vectors
OSRDRM          := $FFB9
GSINIT          := $FFC2
GSREAD          := $FFC5
OSFIND          := $FFCE
OSGBPB          := $FFD1
OSBPUT          := $FFD4
OSBGET          := $FFD7
OSARGS          := $FFDA
OSFILE          := $FFDD
OSRDCH          := $FFE0
OSASCI          := $FFE3
OSNEWL          := $FFE7
OSWRCH          := $FFEE
OSWORD          := $FFF1
OSBYTE          := $FFF4
OSCLI           := $FFF7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Temporary Zeropage Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Command workspace variables (Any *COMMAND entered)
cws_tmp1        := $A8
cws_tmp2        := $A9
cws_tmp3        := $AA
cws_tmp4        := $AB
cws_tmp5        := $AC
cws_tmp6        := $AD
cws_tmp7        := $AE
cws_tmp8        := $AF

; Absolute workspace variables, general Temporary Variables
aws_tmp00       := $B0
aws_tmp01       := $B1
aws_tmp02       := $B2
aws_tmp03       := $B3
aws_tmp04       := $B4
aws_tmp05       := $B5
aws_tmp06       := $B6
aws_tmp07       := $B7
aws_tmp08       := $B8
aws_tmp09       := $B9
aws_tmp10       := $BA
aws_tmp11       := $BB
aws_tmp12       := $BC
aws_tmp13       := $BD
aws_tmp14       := $BE
aws_tmp15       := $BF


; Private workspace variables
; These remain unaltered if the filing system remains selected
pws_tmp00       := $C0
pws_tmp01       := $C1
pws_tmp02       := $C2
pws_tmp03       := $C3
pws_tmp04       := $C4
pws_tmp05       := $C5
pws_tmp06       := $C6
pws_tmp07       := $C7
pws_tmp08       := $C8
pws_tmp09       := $C9
pws_tmp10       := $CA
pws_tmp11       := $CB
pws_tmp12       := $CC
pws_tmp13       := $CD
pws_tmp14       := $CE
pws_tmp15       := $CF

TextPointer     := $F2
paged_ram_copy  := $F4
paged_rom_priv_ws := $0DF0

FSCV            := $021E

DirectoryParam  := $CC
CurrentDrv      := $CD
CurrentCat      := $1082

TubeNoTransferIf0 := $10AE
MMC_STATE       := $10AF
OWCtlBlock      := $10B0

VID             := $10E0
VID2            := VID
MMC_CIDCRC      := VID2+$0E
CHECK_CRC7      := VID2+$10

FilesX8         := $0F05


; FujiNet workspace (similar to MMFS MA+$10XX)
; This provides a dedicated workspace for FujiNet operations
fuji_workspace          = 0  ; Base address for FujiNet workspace - this will eventually vary for MASTER

fuji_filename_buffer    = fuji_workspace + $1000

; FujiNet workspace variables (matching MMFS layout)
fuji_open_channels      = fuji_workspace + $10C0  ; Open channels flag byte
fuji_channel_flag_bit   = fuji_workspace + $10C1  ; Channel flag bit
fuji_intch              = fuji_workspace + $10C2  ; Internal channel handle
fuji_cat_file_offset    = fuji_workspace + $10C3  ; Catalog file offset
fuji_channel_block_size = fuji_workspace + $10C4  ; Channel block size
fuji_saved_x            = fuji_workspace + $10C5  ; Saved X register
fuji_fs_messages_on     = fuji_workspace + $10C6  ; FS messages on flag (on if 0)
fuji_cmd_enabled        = fuji_workspace + $10C7  ; Command enabled flag
fuji_default_dir        = fuji_workspace + $10C9  ; Default directory
fuji_default_drive      = fuji_workspace + $10CA  ; Default drive
fuji_lib_dir            = fuji_workspace + $10CB  ; Library directory
fuji_lib_drive          = fuji_workspace + $10CC  ; Library drive
fuji_wild_hash          = fuji_workspace + $10CD  ; Wildcard hash character
fuji_wild_star          = fuji_workspace + $10CE  ; Wildcard star character
fuji_page               = fuji_workspace + $10CF  ; Page variable
fuji_ram_buffer_size    = fuji_workspace + $10D0  ; RAM buffer size
fuji_source_drive       = fuji_workspace + $10D1  ; Source drive
fuji_dest_drive         = fuji_workspace + $10D2  ; Destination drive
fuji_force_reset        = fuji_workspace + $10D3  ; Force reset flag
fuji_disk_table_index   = fuji_workspace + $10D4  ; Disk table index
fuji_tube_present       = fuji_workspace + $10D6  ; Tube present flag (present if 0)
fuji_gbpb_table_lo      = fuji_workspace + $10D7  ; GBPB table low byte
fuji_gbpb_table_hi      = fuji_workspace + $10D8  ; GBPB table high byte
fuji_text_ptr_offset    = fuji_workspace + $10D9  ; Text pointer offset
fuji_text_ptr_hi        = fuji_workspace + $10DA  ; Text pointer high byte
fuji_param_block_lo     = fuji_workspace + $10DB  ; Parameter block low byte
fuji_param_block_hi     = fuji_workspace + $10DC  ; Parameter block high byte
fuji_error_flag         = fuji_workspace + $10DD  ; Error flag
fuji_card_sort          = fuji_workspace + $10DE  ; Card sort flag



; FujiNet state variables (using unused workspace locations)
fuji_state              = fuji_workspace + $10F0  ; Device state
fuji_current_disk       = fuji_workspace + $10F1  ; Current mounted disk

; FujiNet file operation workspace variables
fuji_operation_type     = fuji_workspace + $10F2  ; Operation type ($85=read, $A5=write)
fuji_buffer_addr        = fuji_workspace + $10F3  ; Buffer address (2 bytes)
fuji_file_offset        = fuji_workspace + $10F5  ; File offset (3 bytes)
fuji_block_size         = fuji_workspace + $10F8  ; Block size (2 bytes)
fuji_current_sector     = fuji_workspace + $10FA  ; Current sector being accessed

; Channel workspace (similar to MMFS $1100-$11BF)
fuji_channel_flags      = fuji_workspace + $1100  ; Channel flags (per channel)
fuji_channel_buffer     = fuji_workspace + $1110  ; Channel buffer pointers

; Channel workspace variables (mapped from MMFS $1110-$111F)
fuji_1111               = fuji_workspace + $1111  ; PTR mid byte  
fuji_1112               = fuji_workspace + $1112  ; PTR high byte
fuji_1113               = fuji_workspace + $1113  ; Buffer page
fuji_1114               = fuji_workspace + $1114  ; EXT low byte
fuji_1115               = fuji_workspace + $1115  ; EXT mid byte
fuji_1116               = fuji_workspace + $1116  ; EXT high byte
fuji_1117               = fuji_workspace + $1117  ; Channel flags
