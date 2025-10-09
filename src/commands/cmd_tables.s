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

        .export cmd_table_info

        .export parameter_table

        .import cmd_fs_close
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
; old cmdtable1
cmd_table_fujifs:
        .byte   $FF                ; Last command number (-1)

        .byte   "CLOSE",     $80+$00
        .byte   "DRIVE",     $80+$01    ; <drive>
; equivalent of .info_cmd_index
cmd_table_info:
        .byte   "INFO",      $80+$02    ; <afsp>
        .byte   $00                     ; End of table

; These are prefixed with "F", e.g. "FBOOT" etc [FILE SYSTEM COMMANDS], help = "*HELP FUTILS"
; old cmdtable4
cmd_table_futils:
        ; 02
        .byte   (cmd_table_futils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "BOOT",      $80+$03    ; <dno>/<dsp>
        .byte   $00                     ; End of table

; COMMAND TABLE - Utils commands [NON-FS COMMANDS], help = "*HELP UTILS"
; old cmdtable2
cmd_table_utils:
        ; 04
        .byte   (cmd_table_utils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "ROMS",      $80
        .byte   $00

; COMMAND TABLE - Help commands [HELP COMMANDS], help = "*HELP"
; old cmdtable3
cmd_table_help:
        ; 06
        .byte   (cmd_table_help_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "FUJI",      $80
        .byte   "FUTILS",    $80
        .byte   "UTILS",     $80
        .byte   $00                     ; End of table

; COMMAND TABLE - File System INIT commands, NO HELP COMMAND
; old cmdtable22
cmd_table_fs:
        ; 0A
        .byte   (cmd_table_fs_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "FUJI", $80
        .byte   $00                     ; End of table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; OLD: cmdaddr1
cmd_table_fujifs_cmds:
        .word   cmd_fs_close-1
        .word   cmd_fs_drive-1
        .word   cmd_fs_info-1
        .word   not_cmd_fujifs-1

; OLD: cmdaddr4
cmd_table_futils_cmds:
        .word   cmd_fs_fboot-1
        .word   not_cmd_futils-1

; OLD: cmdaddr2
cmd_table_utils_cmds:
        .word   cmd_utils_roms-1
        .word   not_cmd_utils-1

; OLD: cmdaddr3
cmd_table_help_cmds:
        .word   cmd_help_fuji-1
        .word   cmd_help_futils-1
        .word   cmd_help_utils-1
        .word   not_cmd_help-1

; OLD: cmdaddr22
cmd_table_fs_cmds:
        .word   cmd_fs_fuji-1
        .word   not_cmd_fs-1

cmd_table_END:

parameter_table:
        .byte '<'|$80, "drive>"                 ; 1
        .byte '<'|$80, "afsp>"                  ; 2
        .byte '<'|$80, "dno>/<dsp>"             ; 3

        .byte $FF
