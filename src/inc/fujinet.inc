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
cmdtab_offset_fujifs = 0

; OLD: cmdtab4
cmdtab_offset_futils = <(cmd_table_futils - cmd_table_fujifs)
; OLD: cmdtab2
cmdtab_offset_utils  = <(cmd_table_utils - cmd_table_fujifs)
; OLD: cmdtab3
cmdtab_offset_help   = <(cmd_table_help - cmd_table_fujifs)
; OLD: cmdtab22
cmdtab_offset_fs     = <(cmd_table_fs - cmd_table_fujifs)


.endif