; FujiNet ROM definitions and constants

        .import cmd_table_fujifs
        .import cmd_table_futils
        .import cmd_table_utils
        .import cmd_table_help
        .import cmd_table_fs

        .import cmd_table_fujifs_cmds
        .import cmd_table_futils_cmds
        .import cmd_table_utils_cmds
        .import cmd_table_help_cmds
        .import cmd_table_fs_cmds

.ifndef FUJINET_INC
FUJINET_INC = 1

        .include "os.inc"

; command table lengths (number of functions)
; used to print appropriate help table ()

; OLD: cmdtab1size
cmdtab_fujifs_cmds_size = <((cmd_table_futils_cmds - cmd_table_fujifs_cmds) / 2 - 1)
; OLD: cmdtab4size
cmdtab_futils_cmds_size = <((cmd_table_utils_cmds - cmd_table_futils_cmds) / 2 - 1)
; OLD: cmdtab2size
cmdtab_utils_cmds_size  = <((cmd_table_help_cmds - cmd_table_utils_cmds) / 2 - 1)
; OLD: cmdtab3size
cmdtab_help_cmds_size   = <((cmd_table_fs_cmds - cmd_table_help_cmds) / 2 - 1)

; unused
; OLD: cmdtab22size
; cmdtab_fs_cmds_size     = (cmd_table_END - cmd_table_fs_cmds) / 2 - 1

; offsets from cmd_table_fujifs
; used to detect the input commands
cmdtab_offset_fujifs    = 0

; OLD: cmdtab4 (0D)
cmdtab_offset_futils    = <(cmd_table_futils - cmd_table_fujifs)
; OLD: cmdtab2 (14)
cmdtab_offset_utils     = <(cmd_table_utils - cmd_table_fujifs)
; OLD: cmdtab3 (1B)
cmdtab_offset_help      = <(cmd_table_help - cmd_table_fujifs)
; OLD: cmdtab22 (2F)
cmdtab_offset_fs        = <(cmd_table_fs - cmd_table_fujifs)

; Shared data pointer for all FujiNet interface implementations
; This provides a consistent interface across all implementations
data_ptr = aws_tmp08

; FujiNet workspace (similar to MMFS MA+$10XX)
; This provides a dedicated workspace for FujiNet operations
fuji_workspace          = $1000  ; Base address for FujiNet workspace

; FujiNet workspace variables (matching MMFS layout)
fuji_open_channels      = fuji_workspace + $10C0  ; Open channels flag byte
fuji_channel_flag_bit   = fuji_workspace + $10C1  ; Channel flag bit
fuji_intch              = fuji_workspace + $10C2  ; Internal channel handle
fuji_cat_file_offset    = fuji_workspace + $10C3  ; Catalog file offset
fuji_channel_block_size = fuji_workspace + $10C4  ; Channel block size
fuji_saved_x            = fuji_workspace + $10C5  ; Saved X register
fuji_fs_messages_on     = fuji_workspace + $10C6  ; FS messages on flag
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
fuji_tube_present       = fuji_workspace + $10D6  ; Tube present flag
fuji_gbpb_table_lo      = fuji_workspace + $10D7  ; GBPB table low byte
fuji_gbpb_table_hi      = fuji_workspace + $10D8  ; GBPB table high byte
fuji_text_ptr_offset    = fuji_workspace + $10D9  ; Text pointer offset
fuji_text_ptr_hi        = fuji_workspace + $10DA  ; Text pointer high byte
fuji_param_block_lo     = fuji_workspace + $10DB  ; Parameter block low byte
fuji_param_block_hi     = fuji_workspace + $10DC  ; Parameter block high byte
fuji_error_flag         = fuji_workspace + $10DD  ; Error flag
fuji_card_sort          = fuji_workspace + $10DE  ; Card sort flag

; Channel workspace (similar to MMFS $1100-$11BF)
fuji_channel_flags      = fuji_workspace + $1100  ; Channel flags (per channel)
fuji_channel_buffer     = fuji_workspace + $1110  ; Channel buffer pointers

; FujiNet state variables (using unused workspace locations)
fuji_state              = $10F0  ; Device state
fuji_current_disk       = $10F1  ; Current mounted disk

; OS constants
filesysno               = $04
filehndl                = $10

.endif