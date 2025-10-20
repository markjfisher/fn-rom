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

        .import cmd_fs_access
        .import cmd_fs_close
        .import cmd_fs_copy
        .import cmd_fs_delete
        .import cmd_fs_destroy
        .import cmd_fs_disc
        .import cmd_fs_dir
        .import cmd_fs_drive
        .import cmd_fs_enable
        .import cmd_fs_ex
        .import cmd_fs_fboot
        .import cmd_fs_form
        .import cmd_fs_free
        .import cmd_fs_fuji
        .import cmd_fs_info
        .import cmd_fs_lib
        .import cmd_fs_map
        .import cmd_fs_rename
        .import cmd_fs_title
        .import cmd_fs_verify
        .import cmd_fs_wipe

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

        .byte   "ACCESS",    $80+$32    ; <afsp> (L) - params 2 and 3
        .byte   "CLOSE",     $80
        .byte   "COPY",      $80+$2C    ; <source> <dest.> <afsp> - params C and 2
        .byte   "DELETE",    $80+$08    ; <fsp>
        .byte   "DESTROY",   $80+$02    ; <afsp>
        .byte   "DIR",       $80+$06    ; (<dir>)
        .byte   "DRIVE",     $80+$01    ; <drive>
        .byte   "ENABLE",    $80
        .byte   "EX",        $80+$06    ; (<dir>)
        .byte   "FORM",      $80+$5F    ; (<drive>)... 40/80 - params 5 and F
        .byte   "FREE",      $80+$04    ; (<drive>)
; equivalent of .info_cmd_index
cmd_table_info:
        .byte   "INFO",      $80+$02    ; <afsp>
        .byte   "LIB",       $80+$06    ; (<dir>)
        .byte   "MAP",       $80+$04    ; (<drive>)
        .byte   "RENAME",    $80+$0D    ; <old fsp> <new fsp>
        .byte   "TITLE",     $80+$0A    ; <title>
        .byte   "VERIFY",    $80+$05    ; (<drive>)...
        .byte   "WIPE",      $80+$02    ; <afsp>
        .byte   $00                     ; End of table

; These are prefixed with "F", e.g. "FBOOT" etc [FILE SYSTEM COMMANDS], help = "*HELP FUTILS"
; old cmdtable4
cmd_table_futils:
        ; 02
        .byte   (cmd_table_futils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "BOOT",      $80+$07    ; <dno>/<dsp>
        .byte   $00                     ; End of table

; COMMAND TABLE - Utils commands [NON-FS COMMANDS], help = "*HELP UTILS"
; old cmdtable2
cmd_table_utils:
        ; 04
        .byte   (cmd_table_utils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "ROMS",      $80+$00    ; no parameter
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

        .byte   "DISC", $80
        .byte   "DISK", $80
        .byte   "FUJI", $80
        .byte   $00                     ; End of table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; OLD: cmdaddr1
cmd_table_fujifs_cmds:
        .word   cmd_fs_access-1
        .word   cmd_fs_close-1
        .word   cmd_fs_copy-1
        .word   cmd_fs_delete-1
        .word   cmd_fs_destroy-1
        .word   cmd_fs_dir-1
        .word   cmd_fs_drive-1
        .word   cmd_fs_enable-1
        .word   cmd_fs_ex-1
        .word   cmd_fs_form-1
        .word   cmd_fs_free-1
        .word   cmd_fs_info-1
        .word   cmd_fs_lib-1
        .word   cmd_fs_map-1
        .word   cmd_fs_rename-1
        .word   cmd_fs_title-1
        .word   cmd_fs_verify-1
        .word   cmd_fs_wipe-1
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
        .word   cmd_fs_disc-1
        .word   cmd_fs_disc-1           ; DISK same as DISC
        .word   cmd_fs_fuji-1
        .word   not_cmd_fs-1

cmd_table_END:

parameter_table:
        .byte '<'|$80, "drive>"                 ; 1
        .byte '<'|$80, "afsp>"                  ; 2
        .byte '('|$80, "L)"                     ; 3
        .byte '('|$80, "<drive>)"               ; 4
        .byte '('|$80, "<drive>)..."            ; 5
        .byte '('|$80, "<dir>)"                 ; 6
        .byte '<'|$80, "dos name>"              ; 7
        .byte '<'|$80, "fsp>"                   ; 8
        .byte '('|$80, "<dos name>)"            ; 9
        .byte '<'|$80, "title>"                 ; A
        .byte '('|$80, "<num>)"                 ; B
        .byte '<'|$80, "source> <dest.>"        ; C
        .byte '<'|$80, "old fsp> <new fsp>"     ; D
        .byte '<'|$80, "filter>"                ; E
        .byte '4'|$80, "0/80"                   ; F

        .byte $FF
