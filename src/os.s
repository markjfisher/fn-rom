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
        .export  ROMSEL

        .export  current_cat
        .export  dfs_cat_num_x8
        .export  FSCV
        .export  paged_rom_priv_ws

        .export  fuji_buf_ws_tmp_buf

        .export  fuji_static_workspace
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
        .export  fuji_text_ptr_offset
        .export  fuji_text_ptr_hi
        .export  fuji_param_block_lo
        .export  fuji_param_block_hi
        .export  fuji_error_flag

        .export  fuji_drive_disk_map
        .export  fuji_state
        .export  fuji_buffer_addr
        .export  fuji_file_offset
        .export  fuji_block_size
        .export  fuji_current_sector
        .export  fuji_current_fs_len
        .export  fuji_current_dir_len
        .export  fuji_current_mount_slot
        .export  fuji_resolve_path_flags
        .export  fuji_disk_slot
        .export  fuji_disk_flags
        .export  fuji_cmd_offset_y
        .export  fuji_filename_len

        .export  fuji_last_state_loc

        .export  fuji_channel_start

        .export  fuji_ch_1101
        .export  fuji_ch_1102
        .export  fuji_ch_1103
        .export  fuji_ch_1104
        .export  fuji_ch_1105
        .export  fuji_ch_1106
        .export  fuji_ch_1107
        .export  fuji_ch_1108
        .export  fuji_ch_1109
        .export  fuji_ch_110A
        .export  fuji_ch_110B

        .export  fuji_ch_name7
        .export  fuji_ch_op
        .export  fuji_ch_dir
        .export  fuji_ch_sec_start
        .export  fuji_ch_bitmask
        .export  fuji_ch_sect_lo
        .export  fuji_ch_sect_hi

        .export  fuji_ch_bptr_low
        .export  fuji_ch_bptr_mid
        .export  fuji_ch_bptr_hi
        .export  fuji_ch_buf_page
        .export  fuji_ch_ext_low
        .export  fuji_ch_ext_mid
        .export  fuji_ch_ext_hi
        .export  fuji_ch_flg

        .export  fuji_cmd_copy_buf_17
        .export  fuji_cmd_cat_buf_8
        .export  fuji_getcat_buf_8

        .export  fuji_buf_ws_tmp_buf

        .export fuji_filev_hi_addr_buf
        .export fuji_filev_load_hi
        .export fuji_filev_exec_hi
        .export fuji_filev_start_hi
        .export fuji_filev_end_hi

        .export  fuji_ch_1118
        .export  fuji_ch_1119
        .export  fuji_ch_111A

        .export  fuji_unknown_11C0
        .export  fuji_unknown_11D0

        .export  _fuji_current_fs_uri
        .export  _fuji_current_dir_path
        .export  _fuji_tx_buffer
        .export  _fuji_rx_buffer
        .export  fuji_bss

        .export  dfs_cat_s0_header
        .export  dfs_cat_s1_header
        .export  dfs_cat_s0_title
        .export  dfs_cat_s1_title
        .export  dfs_cat_cycle
        .export  dfs_cat_num_x8
        .export  dfs_cat_boot_option
        .export  dfs_cat_sect_count
        .export  dfs_cat_file_s0_start
        .export  dfs_cat_file_name
        .export  dfs_cat_file_dir
        .export  dfs_cat_file_s1_start
        .export  dfs_cat_file_load_addr
        .export  dfs_cat_file_exec_addr
        .export  dfs_cat_file_size
        .export  dfs_cat_file_op
        .export  dfs_cat_file_sect

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

        .exportzp  current_drv
        .exportzp  directory_param
        .exportzp  paged_ram_copy
        .exportzp  text_pointer


; OS vectors
ROMSEL          := $FE30
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
pws_tmp11       := $CB   ; ALSO WAS current_host
pws_tmp12       := $CC   ; ALSO directory_param
pws_tmp13       := $CD   ; ALSO current_drv
pws_tmp14       := $CE
pws_tmp15       := $CF

text_pointer    := $F2
paged_ram_copy  := $F4
paged_rom_priv_ws := $0DF0

FSCV            := $021E

; aliases from PWS vars - FIRST 2 OVERWRITTEN BY pws_tmp05,x copying names
; OLD: current_host    := $CB
directory_param := $CC
current_drv     := $CD
; C_SP cc65 stack pointer is at CE and CF

; seems to be pretty random location... why here?
current_cat      := $1082

TubeNoTransferIf0 := $10AE

; 0E00 is a copy of the disk catalog, see fuji_read_catalog in fuji_fs.s
; e.g. 0F05 = Num*8, 0F0C,X = size of nth file where X = 8 + n*8
;
; Catalog header:
; 000-007    First eight bytes of the disk title, padded with spaces.
; 100-103    Last four bytes of disk title, padded with space.
;            The disk title is the directory name in HDFS.
; 104        Disk cycle, HDFS: Key number
; 105        (Number of catalog entries)*8 - offset to end of directory
; 106 b7-b6: zero
;     b5-b4: !Boot option (*OPT 4 value)
;     b3:    0=DFS/WDFS, 1=HDFS
;     b2:    Total number of sectors b10, HDFS: (number of sides)-1
;     b1-b0: Total number of sectors b9-b8
; 107        Total number of sectors b7-b0
; HDFS: The total number of sectors b10 is stored in b7 of byte 000.

; File entries:
; 000-006    Filename and attributes
; 007        Directory and attributes
; 100-101    Load address b0-b15
; 102-103    Exec address b0-b15
; 104-105    File length b0-b15
; 106 b7-b6: Exec address b17-b16, SDDFS: also Load address b17-b16
;     b5-b4: File length b17-b16
;     b3-b2: Load address b17-b16
;     b1-b0: Start sector b9-b8
; 107        Start sector b7-b0

; Catalog header, entry 0:
;              Sector 0                          Sector 1
;  000 001 002 003 004 005 006 007   100 101 102 103 104 105 106 107
; +---+---+---+---+---+---+---+---+ +---+---+---+---+---+---+---+---+
; |          Disk Title           | |   DiskTitle   |Cyc|Num|Op|Sect|
; +---+---+---+---+---+---+---+---+ +---+---+---+---+---+---+---+---+

; File entries, entries 1-31:
;         Sector 0                  Sector 1
;  000 001 002 003 004 005 006 007   100 101 102 103 104 105 106 107
; +---+---+---+---+---+---+---+---+ +---+---+---+---+---+---+---+---+
; |          Filename         |Dir| | Load  | Exec  | Size  |Op|Sect|
; +---+---+---+---+---+---+---+---+ +---+---+---+---+---+---+---+---+

dfs_cat_s0_header       = $0E00
dfs_cat_s1_header       = $0F00

dfs_cat_s0_title        = dfs_cat_s0_header + $00       ; 0E00
dfs_cat_s1_title        = dfs_cat_s1_header + $00       ; 0F00
dfs_cat_cycle           = dfs_cat_s1_header + $04       ; 0F04
dfs_cat_num_x8          = dfs_cat_s1_header + $05       ; 0F05
dfs_cat_boot_option     = dfs_cat_s1_header + $06       ; 0F06
dfs_cat_sect_count      = dfs_cat_s1_header + $07       ; 0F07

dfs_cat_file_s0_start   = dfs_cat_s0_header + $08       ; 0E08
dfs_cat_file_name       = dfs_cat_file_s0_start + $00   ; 0E08 + index * 8
dfs_cat_file_dir        = dfs_cat_file_s0_start + $07   ; 0E0F + index * 8

dfs_cat_file_s1_start   = dfs_cat_s1_header + $08       ; 0F08
dfs_cat_file_load_addr  = dfs_cat_file_s1_start + $00   ; 0F08 + index * 8
dfs_cat_file_exec_addr  = dfs_cat_file_s1_start + $02   ; 0F0A + index * 8
dfs_cat_file_size       = dfs_cat_file_s1_start + $04   ; 0F0C + index * 8
dfs_cat_file_op         = dfs_cat_file_s1_start + $06   ; 0F0E + index * 8
dfs_cat_file_sect       = dfs_cat_file_s1_start + $07   ; 0F0F + index * 8


; FujiNet workspace (similar to MMFS MA+$10XX)
; This provides a dedicated workspace for FujiNet operations
fuji_workspace_root     = 0  ; Base address for FujiNet workspace - this will eventually vary for MASTER
fuji_workspace          = fuji_workspace_root + $1000

; 64 byte buffer for filename 1000-103F, but only used 8 bytes in some places
fuji_filename_buffer    = fuji_workspace + 0

; used in cmd_copy.s, 17 byte buffer $1045 to $1056
fuji_cmd_copy_buf_17    = $1045

; 1057 free?

; 1058-105F used in fs_functions
fuji_getcat_buf_8       = $1058

; used in starCAT, 1060-1067
fuji_cmd_cat_buf_8      = $1060

; see @filev_entry.s, the buffer is 1074 to 107B
fuji_filev_hi_addr_buf  = $1074  ; start of the 8 byte buffer
fuji_filev_load_hi      = $1074  ; LOAD 2 bytes for 16 bits of the 32 bit word
fuji_filev_exec_hi      = $1076  ; EXEC 2 bytes for 16 bits of the 32 bit word
fuji_filev_start_hi     = $1078  ; START 2 bytes for 16 bits of the 32 bit word
fuji_filev_end_hi       = $107A  ; END 2 bytes for 16 bits of the 32 bit word

; The low 2 bytes go into BC to C3 for equiv parts.
; the filename pointer goes into BA/BB


; 1090 seems to be a copy of BC to CB, restoring it in MMC_END

; 1090-109F
fuji_buf_ws_tmp_buf     = $1090

; workspace_utils.s references 10C0-10EF and 1100-11BF as static workspace

; FujiNet workspace variables (matching MMFS layout)
fuji_static_workspace   = fuji_workspace + $C0

fuji_open_channels      = fuji_static_workspace + $00  ; Open channels flag byte
fuji_channel_flag_bit   = fuji_static_workspace + $01  ; Channel flag bit
fuji_intch              = fuji_static_workspace + $02  ; Internal channel handle
fuji_cat_file_offset    = fuji_static_workspace + $03  ; Catalog file offset
fuji_channel_block_size = fuji_static_workspace + $04  ; Channel block size
fuji_saved_x            = fuji_static_workspace + $05  ; Saved X register
fuji_fs_messages_on     = fuji_static_workspace + $06  ; FS messages on flag (on if 0)
fuji_cmd_enabled        = fuji_static_workspace + $07  ; Command enabled flag
fuji_default_dir        = fuji_static_workspace + $09  ; Default directory
fuji_default_drive      = fuji_static_workspace + $0A  ; Default drive
fuji_lib_dir            = fuji_static_workspace + $0B  ; Library directory
fuji_lib_drive          = fuji_static_workspace + $0C  ; Library drive
fuji_wild_hash          = fuji_static_workspace + $0D  ; Wildcard hash character
fuji_wild_star          = fuji_static_workspace + $0E  ; Wildcard star character
fuji_page               = fuji_static_workspace + $0F  ; Page variable
fuji_ram_buffer_size    = fuji_static_workspace + $10  ; RAM buffer size
fuji_source_drive       = fuji_static_workspace + $11  ; Source drive
fuji_dest_drive         = fuji_static_workspace + $12  ; Destination drive
fuji_force_reset        = fuji_static_workspace + $13  ; Force reset flag
fuji_disk_table_index   = fuji_static_workspace + $14  ; Disk table index, used to store the current fujinet Mount slot. 2nd byte unused
fuji_tube_present       = fuji_static_workspace + $15  ; Tube present flag (present if 0)
fuji_text_ptr_offset    = fuji_static_workspace + $16  ; Text pointer offset
fuji_text_ptr_hi        = fuji_static_workspace + $17  ; Text pointer high byte
fuji_param_block_lo     = fuji_static_workspace + $18  ; Parameter block low byte
fuji_param_block_hi     = fuji_static_workspace + $19  ; Parameter block high byte
fuji_error_flag         = fuji_static_workspace + $1A  ; Error flag

; FujiNet drive-to-disk mapping (like MMFS DRIVE_INDEX)
; Each byte contains the disk image number mounted in that drive (0-255)
; 0xFF = no disk mounted
fuji_drive_disk_map     = fuji_static_workspace + $1B  ; 4 bytes: drives 0-3, 10DB to 10DE

; FujiNet state variables (using unused workspace locations)
fuji_state              = fuji_static_workspace + $1F  ; Device state
fuji_buffer_addr        = fuji_static_workspace + $20  ; Buffer address (2 bytes)
fuji_file_offset        = fuji_static_workspace + $22  ; File offset (3 bytes)

; FujiNet file operation workspace variables
fuji_block_size         = fuji_static_workspace + $25  ; Block size (2 bytes)
fuji_current_sector     = fuji_static_workspace + $27  ; Current sector being accessed

; Current filesystem selection state for URI-based commands
fuji_current_fs_len     = fuji_static_workspace + $28  ; Current filesystem URI length
fuji_current_dir_len    = fuji_static_workspace + $29  ; Current directory length
fuji_current_mount_slot = fuji_static_workspace + $2A  ; Current FujiNet persisted mount slot (0-based)
fuji_resolve_path_flags = fuji_static_workspace + $2B  ; ResolvePath response: bit0=isDir, bit1=exists (set by fuji_file_resolve_path)
fuji_disk_slot          = fuji_static_workspace + $2C  ; current fujinet mount slot for defaults, 0-based internally, 1 based on the wire
fuji_disk_flags         = fuji_static_workspace + $2D  ; flags for disk
fuji_current_host_len   = fuji_static_workspace + $2E  ; Current filesystem URI length

fuji_cmd_offset_y       = fuji_static_workspace + $2F  ; save value of the command offset in Y given to CMD functions on entry.
fuji_filename_len       = fuji_static_workspace + $30  ; the filename part of the FS URI input by *FIN

; LAST location for the copy state in workspace_utils.s function to understand
fuji_last_state_loc     = fuji_static_workspace + $30  ; effectively $10F0

; see SetupChannelInfoBlock_Yintch
; copies from &E08 to &1100, and &F08 to &1100+1 in a loop.
; seemingly interweving catalog data

; channel info block
fuji_channel_start      = fuji_workspace + $1100  ; name byte 1
fuji_ch_1101            = fuji_channel_start + $01 ; load addr byte 1
fuji_ch_1102            = fuji_channel_start + $02 ; name byte 2
fuji_ch_1103            = fuji_channel_start + $03 ; load addr byte 2
fuji_ch_1104            = fuji_channel_start + $04 ; name byte 3
fuji_ch_1105            = fuji_channel_start + $05 ; exec addr byte 1
fuji_ch_1106            = fuji_channel_start + $06 ; name byte 4
fuji_ch_1107            = fuji_channel_start + $07 ; exec addr byte 2
fuji_ch_1108            = fuji_channel_start + $08 ; name byte 5
fuji_ch_1109            = fuji_channel_start + $09 ; size byte 1
fuji_ch_110A            = fuji_channel_start + $0A ; name byte 6
fuji_ch_110B            = fuji_channel_start + $0B ; size byte 2
fuji_ch_name7           = fuji_channel_start + $0C ; name byte 7
fuji_ch_op              = fuji_channel_start + $0D ; "op" mixed byte
fuji_ch_dir             = fuji_channel_start + $0E ; directory
fuji_ch_sec_start       = fuji_channel_start + $0F ; start sector

; Channel workspace variables (mapped from MMFS $1110-$111F)
fuji_ch_bptr_low        = fuji_channel_start + $10  ; PTR low byte
fuji_ch_bptr_mid        = fuji_channel_start + $11  ; PTR mid byte  
fuji_ch_bptr_hi         = fuji_channel_start + $12  ; PTR high byte
fuji_ch_buf_page        = fuji_channel_start + $13  ; Buffer page ?? IS THIS CORRECT?
fuji_ch_ext_low         = fuji_channel_start + $14  ; EXT low byte
fuji_ch_ext_mid         = fuji_channel_start + $15  ; EXT mid byte
fuji_ch_ext_hi          = fuji_channel_start + $16  ; EXT high byte
fuji_ch_flg             = fuji_channel_start + $17  ; Channel flags - EOF usage here
fuji_ch_1118            = fuji_channel_start + $18  ; ???
fuji_ch_1119            = fuji_channel_start + $19  ; ??? - sector count
fuji_ch_111A            = fuji_channel_start + $1A  ; ??? - len 2
fuji_ch_bitmask         = fuji_channel_start + $1B  ; Bit mask
fuji_ch_sect_lo         = fuji_channel_start + $1C  ; buffer sector low
fuji_ch_sect_hi         = fuji_channel_start + $1D  ; buffer sector high

; used in initdfs_reset, initialise static workspace
; In mmfs100.asm "Reset the *DDRIVE table (MMFS2)"
fuji_unknown_11C0       = fuji_workspace + $1C0
fuji_unknown_11D0       = fuji_workspace + $1D0

; ASSUME THE CHANNEL DATA DOES NOT GO BEYOND $1130

; 80 byte buffer for current HOST string - some of this is copied during static/private workspace shuffle - TODO: need to sort all that out.
_fuji_current_host_uri   = fuji_workspace + $11B0

; 80 byte buffer - TODO review lengths, we can only input 64 chars in param_get_string
_fuji_current_fs_uri     = fuji_workspace + $0200

; 80 byte buffer, technically cannot be more than "uri - scheme length"
_fuji_current_dir_path   = fuji_workspace + $0250

; 96 byte TX buffer - need to see how this pans out
_fuji_tx_buffer          = fuji_workspace + $02A0

; 512 byte RX buffer - does this need to be 512 bytes?
_fuji_rx_buffer          = fuji_workspace + $0300


; the start of where BSS should be defined for CC65, see fujinet-rom.cfg
; this extends up to 1900 for room for temporary vars, and global C vars (trying not to use those - revisit this when we move to ".res" for allocating memory).
fuji_bss                = fuji_workspace + $0500
