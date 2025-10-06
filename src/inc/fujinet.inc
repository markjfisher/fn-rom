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

; FujiNet state variables (using unused workspace locations)
fuji_state              = $10F0  ; Device state
fuji_current_disk       = $10F1  ; Current mounted disk

; OS constants
filesysno               = $04
filehndl                = $10

.endif