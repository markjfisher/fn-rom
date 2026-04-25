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
        .export  TUBE_BASE

        .export  TUBE_R1_STATUS
        .export  TUBE_R1_DATA
        .export  TUBE_R2_STATUS
        .export  TUBE_R2_DATA
        .export  TUBE_R3_STATUS
        .export  TUBE_R3_DATA
        .export  TUBE_R4_STATUS
        .export  TUBE_R4_DATA

        .export  tube_code
        .export  gbpb_tube
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
        .export  fuji_channel_scratch
        .export  fuji_saved_x
        .export  fuji_saved_i
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
        .export  fuji_current_host_len
        .export  fuji_filename_len
        .export  fuji_own_sws_indicator

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
        .export  fuji_ch_handle_low
        .export  fuji_ch_handle_high

        .export  fuji_ch_bptr_low
        .export  fuji_ch_bptr_mid
        .export  fuji_ch_bptr_hi
        .export  fuji_ch_buf_page
        .export  fuji_ch_ext_low
        .export  fuji_ch_ext_mid
        .export  fuji_ch_ext_hi
        .export  fuji_ch_flg

        .export  fuji_cmd_copy_buf_17
        .export  fuji_getcat_buf_8
        .export  fuji_cmd_cat_buf_8
        .export  gbpb_buf_0c
        .export  gbpb_file_handle
        .export  gbpb_ctl_blk_mem_ptr_host
        .export  gbpb_seqptr

        .export  fuji_buf_ws_tmp_buf

        .export  fuji_filev_hi_addr_buf
        .export  fuji_filev_load_hi
        .export  fuji_filev_exec_hi
        .export  fuji_filev_start_hi
        .export  fuji_filev_end_hi

        .export  fuji_gbpbv_blk_save_ptr
        .export  fuji_gbpbv_tube_op

        .export  fuji_ch_1118
        .export  fuji_ch_sect_cnt
        .export  fuji_ch_111A

        .export  fuji_ax_save
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
        .exportzp  fuji_bus_tx_payload_lo
        .exportzp  fuji_bus_tx_payload_hi
        .exportzp  fuji_bus_tx_device
        .exportzp  fuji_bus_tx_command
        .exportzp  cws_tmp1
        .exportzp  cws_tmp2
        .exportzp  cws_tmp3
        .exportzp  cws_tmp4
        .exportzp  cws_tmp5
        ; 16-bit pointer to FujiBus packet buffer in PWS (aliases cws_tmp4/5). Set by
        ; set_fuji_data_buffer_ptr from fuji_begin_transaction; do not use as scratch
        ; across any call that may begin a Fuji transaction (or save Y elsewhere).
        .exportzp  buffer_ptr
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
        .exportzp  data_ptr

; OS vectors
ROMSEL          := $FE30
TUBE_BASE       := $FEE0
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

; Used for data_buffer_ptr indirection
buffer_ptr      := cws_tmp4

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
; start of ZP values saved during fuji_begin_transaction (into 1090-109F)
aws_tmp12       := $BC
aws_tmp13       := $BD
aws_tmp14       := $BE
aws_tmp15       := $BF

; FujiBus TX — before jsr fujibus_send_packet: payload length in A/X; payload pointer below.
; Device/command slots are defined after pws_tmp15 — must not use aws_tmp14/15 (see there).
fuji_bus_tx_payload_lo  := aws_tmp10
fuji_bus_tx_payload_hi  := aws_tmp11


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
pws_tmp10       := $CA   ; use this as 2 byte data_ptr
pws_tmp11       := $CB   ; ALSO WAS current_host
; END of ZP locations saved in fuji_begin_transaction
pws_tmp12       := $CC   ; ALSO directory_param
pws_tmp13       := $CD   ; ALSO current_drv
pws_tmp14       := $CE   ; cc65 uses these 2 as c_sp
pws_tmp15       := $CF

; FujiBus TX device/command — staged here so we do not clobber aws_tmp14/15: fuji_read_block_data
; (fuji_serial.s) stores fuji_block_size / full-sector loop count in aws_tmp14/15 during LOAD.
fuji_bus_tx_device      := pws_tmp14
fuji_bus_tx_command     := pws_tmp15

text_pointer    := $F2
paged_ram_copy  := $F4
paged_rom_priv_ws := $0DF0

FSCV            := $021E

; aliases from PWS vars - FIRST 2 OVERWRITTEN BY pws_tmp05,x copying names
; OLD: current_host    := $CB
directory_param := $CC
current_drv     := $CD
; C_SP cc65 stack pointer is at CE and CF

; use pws_tmp10/11 for a generic data pointer
data_ptr        := $CA

tube_code         := $0406      ; MMFS defined in SYSVARS.asm, documented in New Advanced User Guide just as "call tube code"
TubeNoTransferIf0 := $10AE

TUBE_R1_STATUS    := TUBE_BASE + $00
TUBE_R1_DATA      := TUBE_BASE + $01
TUBE_R2_STATUS    := TUBE_BASE + $02
TUBE_R2_DATA      := TUBE_BASE + $03
TUBE_R3_STATUS    := TUBE_BASE + $04
TUBE_R3_DATA      := TUBE_BASE + $05
TUBE_R4_STATUS    := TUBE_BASE + $06
TUBE_R4_DATA      := TUBE_BASE + $07

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

; used in starCAT, 1060-1067.
fuji_cmd_cat_buf_8      = $1060

; also used in gbpb_functions.s as 1060-106C
gbpb_buf_0c             = $1060

; named locations within the buffer
gbpb_file_handle          = $1060  ; 1 byte file handle
gbpb_ctl_blk_mem_ptr_host = $1061  ; 2 bytes, used in gbpb_b8_memptr


; gbpb uses $1069-106C in seqptr loop as a 4 byte pointer (pling)
; document this better when we know more about it - it's also shared in above
gbpb_seqptr             = $1069


; see @filev_entry.s, the buffer is 1074 to 107B
fuji_filev_hi_addr_buf  = $1074  ; start of the 8 byte buffer
fuji_filev_load_hi      = $1074  ; LOAD 2 bytes for 16 bits of the 32 bit word
fuji_filev_exec_hi      = $1076  ; EXEC 2 bytes for 16 bits of the 32 bit word
fuji_filev_start_hi     = $1078  ; START 2 bytes for 16 bits of the 32 bit word
fuji_filev_end_hi       = $107A  ; END 2 bytes for 16 bits of the 32 bit word

; The low 2 bytes go into BC to C3 for equiv parts.
; the filename pointer goes into BA/BB

; GBPB USAGE IN MMFS
; $017D/107E save pointer to command block (MMFS)
fuji_gbpbv_blk_save_ptr = $107D  ; 2 bytes pointer to gbpbv param block
fuji_gbpbv_tube_op      = $107F  ; used in gbpb_gosub

; $1081      used in tube checking
gbpb_tube               = $1081

current_cat             = $1082
; in initialising, both current_cat and current_cat+1 are set to ascii "0"

; $10D7/10D8 copied from GBPBV_TABLE indexed by command, but in fujinet it's fuji_param_block_lo

; 1090 seems to be a copy of BC to CB, restoring it in MMC_END / transaction_end

; 1090-109F
fuji_buf_ws_tmp_buf     = $1090

; workspace_utils.s references 10C0-10FF and 1100-11BF as static workspace
; this is essentially channels/files information for a filing system
; allowing 

; FujiNet workspace variables (matching MMFS layout)
fuji_static_workspace   = fuji_workspace + $C0

; A few locations are kept in same place as the DFS equivalents
fuji_open_channels      = fuji_static_workspace + $00  ; Open channels flag byte, each bit represents a channel, 1 is open, 0 is closed
fuji_channel_flag_bit   = fuji_static_workspace + $01  ; Channel flag bit
fuji_intch              = fuji_static_workspace + $02  ; Internal channel handle (high 3 bits)
fuji_cat_file_offset    = fuji_static_workspace + $03  ; Catalog file offset
fuji_channel_scratch    = fuji_static_workspace + $04  ; General purpose scratch byte
fuji_saved_x            = fuji_static_workspace + $05  ; Saved X register
fuji_fs_messages_on     = fuji_static_workspace + $06  ; FS messages on flag (on if 0)
fuji_disk_table_index   = fuji_static_workspace + $07  ; Disk table index, used to store the current fujinet Mount slot. 2nd byte unused
fuji_cmd_enabled        = fuji_static_workspace + $08  ; Command enabled flag
fuji_error_flag         = fuji_static_workspace + $09  ; Error flag
fuji_default_dir        = fuji_static_workspace + $0A  ; Default directory
fuji_default_drive      = fuji_static_workspace + $0B  ; Default drive
fuji_lib_dir            = fuji_static_workspace + $0C  ; Library directory
fuji_lib_drive          = fuji_static_workspace + $0D  ; Library drive
fuji_wild_hash          = fuji_static_workspace + $0E  ; Wildcard hash character
fuji_wild_star          = fuji_static_workspace + $0F  ; Wildcard star character
fuji_page               = fuji_static_workspace + $10  ; Page variable
fuji_ram_buffer_size    = fuji_static_workspace + $11  ; RAM buffer size
fuji_source_drive       = fuji_static_workspace + $12  ; Source drive
fuji_dest_drive         = fuji_static_workspace + $13  ; Destination drive
fuji_text_ptr_offset    = fuji_static_workspace + $14  ; Text pointer offset
fuji_text_ptr_hi        = fuji_static_workspace + $15  ; Text pointer high byte
fuji_tube_present       = fuji_static_workspace + $16  ; Tube present flag (present if 0)
fuji_param_block_lo     = fuji_static_workspace + $17  ; Parameter block low byte
fuji_param_block_hi     = fuji_static_workspace + $18  ; Parameter block high byte

; FujiNet drive-to-disk mapping (like MMFS DRIVE_INDEX)
; Each byte contains the disk image number mounted in that drive (0-255)
; 0xFF = no disk mounted
fuji_drive_disk_map     = fuji_static_workspace + $19  ; 4 bytes: drives 0-3, 10D9 to 10DC

; FujiNet state variables (using unused workspace locations)
fuji_state              = fuji_static_workspace + $1D  ; Device state
fuji_buffer_addr        = fuji_static_workspace + $1E  ; Buffer address (2 bytes)
fuji_file_offset        = fuji_static_workspace + $20  ; File offset (3 bytes)

; FujiNet file operation workspace variables
fuji_block_size         = fuji_static_workspace + $23  ; Block size (2 bytes)
fuji_current_sector     = fuji_static_workspace + $25  ; Current sector being accessed (2 bytes)

; Current filesystem selection state for URI-based commands
fuji_current_fs_len     = fuji_static_workspace + $27  ; Current filesystem URI length (host + path)
fuji_current_dir_len    = fuji_static_workspace + $28  ; Current directory length
; this doesn't look like it's used: is it a dupe of fuji_disk_slot?
fuji_current_mount_slot = fuji_static_workspace + $29  ; Current FujiNet persisted mount slot (0-based)
fuji_resolve_path_flags = fuji_static_workspace + $2A  ; ResolvePath response: bit0=isDir, bit1=exists (set by fuji_file_resolve_path)
fuji_disk_slot          = fuji_static_workspace + $2B  ; current fujinet mount slot for defaults, 0-based internally, 1 based on the wire
fuji_disk_flags         = fuji_static_workspace + $2C  ; flags for disk
fuji_current_host_len   = fuji_static_workspace + $2D  ; Current filesystem URI length

fuji_filename_len       = fuji_static_workspace + $2E  ; the filename part of the FS URI input by *FIN

; These 2 need to be in this order, as there is an optimization to use INY to index the owns sws indicator flag
fuji_force_reset        = fuji_static_workspace + $2F  ; Force reset flag
fuji_own_sws_indicator  = fuji_static_workspace + $30  ; Used to check if we currently own the SWS

; END OF STATE WE WILL SAVE TO PWS WHEN FILE SYSTEMS SWAP

; Saved IRQ-disable state for temporarily enabling IRQs during FujiBus I/O.
; 0 = IRQs were enabled on entry, nonzero = IRQs were disabled on entry.
; Must not overlap with any MMFS-mapped fields; kept outside the MMFS copy range.
fuji_saved_i            = fuji_static_workspace + $31

; 2 byte buffer for stashing AX registers for saving result while restoring state.
fuji_ax_save            = fuji_static_workspace + $32   ; 2 bytes, don't need to save it

; FINAL LOCATION CAN BE + $3F

; LAST location for the copy state in workspace_utils.s function to understand
; Note this does not have to be all the values above, we have 10F1 to 10FF for general variables
fuji_last_state_loc     = fuji_static_workspace + $30  ; effectively $10F0


; Advanced disk guide describes how 1200-12FF is for open file 1
; 1300-13FF for open file 2, ...etc up to 1600-16FF for open file 5
; in MMFS the channel can go from 1-7, so into 1800-18FF.
; This doesn't seem right, as the PAGE in MMFS is 1900, with 2 pages allocated for private workspace (1700 to 1900)
; which suggests only 5 files can be open.


; see SetupChannelInfoBlock_Yintch
; copies from &E08 to &1100, and &F08 to &1100+1 in a loop.
; interweving catalog data

; channel info block
fuji_channel_start      = fuji_workspace_root + $1100  ; name byte 1
fuji_ch_1101            = fuji_channel_start + $01 ; load addr byte 1
fuji_ch_1102            = fuji_channel_start + $02 ; name byte 2
fuji_ch_1103            = fuji_channel_start + $03 ; load addr byte 2
fuji_ch_1104            = fuji_channel_start + $04 ; name byte 3
fuji_ch_1105            = fuji_channel_start + $05 ; exec addr byte 1
fuji_ch_1106            = fuji_channel_start + $06 ; name byte 4
fuji_ch_1107            = fuji_channel_start + $07 ; exec addr byte 2
fuji_ch_1108            = fuji_channel_start + $08 ; name byte 5
fuji_ch_1109            = fuji_channel_start + $09 ; size byte 1 (of 3)
fuji_ch_110A            = fuji_channel_start + $0A ; name byte 6
fuji_ch_110B            = fuji_channel_start + $0B ; size byte 2 (of 3)
fuji_ch_name7           = fuji_channel_start + $0C ; name byte 7 - high bit set means READ ONLY (findv_entry)
fuji_ch_op              = fuji_channel_start + $0D ; "op" mixed byte
fuji_ch_dir             = fuji_channel_start + $0E ; directory -> directory_param when setting drive from current channel info
fuji_ch_sec_start       = fuji_channel_start + $0F ; start sector

; Channel workspace variables (mapped from MMFS $1110-$111F)
fuji_ch_bptr_low        = fuji_channel_start + $10  ; PTR low byte
fuji_ch_bptr_mid        = fuji_channel_start + $11  ; PTR mid byte  
fuji_ch_bptr_hi         = fuji_channel_start + $12  ; PTR high byte
fuji_ch_buf_page        = fuji_channel_start + $13  ; Buffer page, i.e. $12 to $18 (see setup_channel_info_block_yintch), oh wow taking us up to most of allocated memory under PAGE - this is what uses it all
fuji_ch_ext_low         = fuji_channel_start + $14  ; EXT low byte
fuji_ch_ext_mid         = fuji_channel_start + $15  ; EXT mid byte
fuji_ch_ext_hi          = fuji_channel_start + $16  ; EXT high byte
fuji_ch_flg             = fuji_channel_start + $17  ; Channel flags; see below for breakdown
fuji_ch_1118            = fuji_channel_start + $18  ; ??? UNUSED
fuji_ch_sect_cnt        = fuji_channel_start + $19  ; Sector Count
fuji_ch_111A            = fuji_channel_start + $1A  ; size byte 3 (of 3)
fuji_ch_bitmask         = fuji_channel_start + $1B  ; Bit mask
fuji_ch_sect_lo         = fuji_channel_start + $1C  ; buffer sector low
fuji_ch_sect_hi         = fuji_channel_start + $1D  ; buffer sector high
fuji_ch_handle_low      = fuji_channel_start + $1E  ; handle for fujinet resources - low
fuji_ch_handle_high     = fuji_channel_start + $1F  ; handle for fujinet resources - high


; Breakdown of fuji_ch_flg
; bit 0-1 = Drive number (0-3)
; bit   2 = (unused?)
; bit   3 = (unused?)
; bit   4 = at EOF
; bit   5 = update cat file len when channel closed. if not set then there is no change in file size to write
; bit   6 = write buffer if set
; bit   7 = (-ve) used for "if buffer ok"


; The channels are stored in blocks of $20 bytes.
; I believe there are only 5 channels available, and then above that the memory is free for use (11C0-11FF)
; 0=1100, 1=1120, 2=1140, 3=1160, 4=1180, 5=11A0, [6=11C0, 7=11E0]
; The offsets from 1100 are also the YINTCH value! A0 = [101]0 0000, high 3 bits = 5, which matches the index value.

; so we have FREE MEMORY of 64 bytes we can use later
; Confirmed in is_file_open_yoffset which starts looking for channels from A0 down

; used in initdfs_reset, initialise static workspace
; In mmfs100.asm "Reset the *DDRIVE table (MMFS2)"
; in MM32.asm, 11C0-11DF is marked as "drive table", so I'm guessing 11C0-11FF is spare memory
; fuji_unknown_11C0       = fuji_workspace + $01C0 ; this is channel 6 start block? If only 5 allowed, this is additional area I don't yet understand
; fuji_unknown_11D0       = fuji_workspace + $01D0 ; above + $10, seems like fuji_ch_bptr_low if this is a buffer, but could be part of the 11C0-11FF being for general usage...


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BUFFERS - NEED TO REVIEW THEIR USAGE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; these should be the claimed pages from PWS (usually 1700-18FF)

; Canonical host URI from *FHOST ResolvePath lives in PWS at FUJI_HOST_URI_OFFSET (second
; 80-byte slot after the packet slice). Directory path for display is the suffix of that
; string; length in fuji_current_dir_len (wire path_len); PATH = host base + (host_len - dir_len).
; Use fuji_host_uri_ptr() / get_fuji_host_uri_addr_to_aws_tmp00.

; FS URI scratch (80 bytes) in PWS — FUJI_FS_URI_OFFSET / fuji_fs_uri_ptr (working cwd for FLS/FIN).

; FujiBus packet buffer: lives in private workspace (see FUJI_PWS_* in fujinet.inc).
; Runtime base address is set in buffer_ptr (cws_tmp4/5) by set_fuji_data_buffer_ptr.

; should be free from $13C0 to $1500


; the start of where BSS should be defined for CC65, see fujinet-rom.cfg
; this extends up to 1900 for room for temporary vars, and global C vars (trying not to use those - revisit this when we move to ".res" for allocating memory).
fuji_bss                = fuji_workspace + $0500
