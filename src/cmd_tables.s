; Command tables for FujiNet ROM
        .export cmd_table_fujifs
        .export cmd_table_futils
        .export cmd_table_utils
        .export cmd_table_help
        .export cmd_table_fs

        .export cmd_table_fujifs_cmds
        .export cmd_table_futils_cmds
        .export cmd_table_utils_cmds
        .export cmd_table_help_cmds
        .export cmd_table_fs_cmds

        .export parameter_table

        .import cmd_fs_drive
        .import cmd_fs_fboot
        .import cmd_fs_fuji
        .import cmd_fs_info
        .import cmd_help_fuji
        .import cmd_help_futils
        .import cmd_help_utils
        .import cmd_utils_roms
        .import not_cmd_fs
        .import not_cmd_fujifs
        .import not_cmd_futils
        .import not_cmd_help
        .import not_cmd_utils

        .segment "RODATA"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND STRINGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; COMMAND TABLE - FujiNet file system commands [FILE SYSTEM COMMANDS], help = "*HELP FUJI"
cmd_table_fujifs:
        .byte   $FF                ; Last command number (-1)

        .byte   "DRIVE",     $80+$01    ; <drive>
        .byte   "INFO",      $80+$02    ; <afsp>
        .byte   $00                     ; End of table

; These are prefixed with "F", e.g. "FBOOT" etc [FILE SYSTEM COMMANDS], help = "*HELP FUTILS"
cmd_table_futils:
        .byte   (cmd_table_futils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "BOOT",      $80+$03    ; <dno>/<dsp>
        .byte   $00                     ; End of table

; COMMAND TABLE - Utils commands [NON-FS COMMANDS], help = "*HELP UTILS"
cmd_table_utils:
        .byte   (cmd_table_utils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "ROMS",      $80
        .byte   $00

; COMMAND TABLE - Help commands [HELP COMMANDS], help = "*HELP"
cmd_table_help:
        .byte   (cmd_table_help_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "FUJI",      $80
        .byte   "FUTILS",    $80
        .byte   "UTILS",     $80
        .byte   $00                     ; End of table

; COMMAND TABLE - File System INIT commands, NO HELP COMMAND
cmd_table_fs:
        .byte   (cmd_table_fs_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "FUJI", $80
        .byte   $00                     ; End of table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_table_fujifs_cmds:
        .word   cmd_fs_drive-1
        .word   cmd_fs_info-1
        .word   not_cmd_fujifs-1

cmd_table_futils_cmds:
        .word   cmd_fs_fboot-1
        .word   not_cmd_futils-1

cmd_table_utils_cmds:
        .word   cmd_utils_roms-1
        .word   not_cmd_utils-1

cmd_table_help_cmds:
        .word   cmd_help_fuji-1
        .word   cmd_help_futils-1
        .word   cmd_help_utils-1
        .word   not_cmd_help-1

cmd_table_fs_cmds:
        .word   cmd_fs_fuji-1
        .word   not_cmd_fs-1

cmd_table_END:

parameter_table:
        .byte '<'|$80, "drive>"                 ; 1
        .byte '<'|$80, "afsp>"                  ; 2
        .byte '<'|$80, "dno>/<dsp>"             ; 3

        .byte $FF