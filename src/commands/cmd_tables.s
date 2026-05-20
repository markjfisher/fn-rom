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
        .export cmd_table_END

        .export cmd_table_info

        .export parameter_table

        .import cmd_fs_access
        .import cmd_fs_close
        .import cmd_fs_copy
        .import cmd_fs_delete
        .import cmd_fs_destroy
        .import cmd_fs_dir
        .import cmd_fs_disc
        .import cmd_fs_drive
        .import cmd_fs_enable
        .import cmd_fs_ex
        .import cmd_fs_fboot
        .import cmd_fs_fcd
        .import cmd_fs_fdrive
        .import cmd_fs_fhost
        .import cmd_fs_fin
        .import cmd_fs_fjson
        .import cmd_fs_flist
        .import cmd_fs_fmount
        .import cmd_fs_fnew
        .import cmd_fs_form
        .import cmd_fs_fout
        .import cmd_fs_free
        .import cmd_fs_fuji
        .import cmd_fs_funmount
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

        ; .import cmd_fs_fls



; These all come after the HEADER in the ROM.
; and ensures all the strings are in the same page as each other.
        .segment "RODATA"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND STRINGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; NOTE: The tables have to be in the same order
; as the old cmdtable* defines as there is logic to
; determine if we're after a certain table to start
; printing 'F' at the beginning of the command.
;
; Command entry format:
;   .byte "COMMAND", $80|<param slot 1>, <param slot 2>
; Bit 7 of the first parameter byte terminates the command text for the
; matcher/help printer, while bits 0-6 still hold parameter slot 1.

; COMMAND TABLE - FujiNet file system commands [FILE SYSTEM COMMANDS], help = "*HELP FUJI"
; old cmdtable1
cmd_table_fujifs:
        .byte   $FF                ; Last command number (-1)

        .byte   "ACCESS",    $82, $14         ; <afsp> (L)
        .byte   "CLOSE",     $80, $00
        .byte   "COPY",      $8F, $02         ; <source> <dest.> <afsp>
        .byte   "DELETE",    $81, $00         ; <fsp>
        .byte   "DESTROY",   $82, $00         ; <afsp>
        .byte   "DIR",       $86, $00         ; (<dir>)
        .byte   "DRIVE",     $83, $00         ; <drive>
        .byte   "ENABLE",    $80, $00
        .byte   "EX",        $86, $00         ; (<dir>)
        .byte   "FORM",      $85, $12         ; (<drive>)... 40/80
        .byte   "FREE",      $84, $00         ; (<drive>)
; equivalent of .info_cmd_index
cmd_table_info:
        .byte   "INFO",      $82, $00         ; <afsp>
        .byte   "LIB",       $86, $00         ; (<dir>)
        .byte   "MAP",       $84, $00         ; (<drive>)
        .byte   "RENAME",    $90, $00         ; <old fsp> <new fsp>
        .byte   "TITLE",     $8D, $00         ; <title>
        .byte   "VERIFY",    $85, $00         ; (<drive>)...
        .byte   "WIPE",      $82, $00         ; <afsp>
        .byte   $00                     ; End of table

; COMMAND TABLE - Utils commands [NON-FS COMMANDS], help = "*HELP UTILS"
; old cmdtable2
cmd_table_utils:
        .byte   (cmd_table_utils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "ROMS",      $80, $00         ; no parameter
        .byte   $00


; COMMAND TABLE - File System INIT commands, NO HELP COMMAND
; old cmdtable22
cmd_table_fs:
        .byte   (cmd_table_fs_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "DISC", $80, $00
        .byte   "DISK", $80, $00
        .byte   "FUJI", $80, $00
        .byte   $00                     ; End of table

; COMMAND TABLE - Help commands [HELP COMMANDS], help = "*HELP"
; old cmdtable3
cmd_table_help:
        .byte   (cmd_table_help_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "FUJI",      $80, $00
        .byte   "FUTILS",    $80, $00
        .byte   "UTILS",     $80, $00
        .byte   $00                     ; End of table

; These are prefixed with "F", e.g. "FBOOT" etc [FILE SYSTEM COMMANDS], help = "*HELP FUTILS"
; old cmdtable4
cmd_table_futils:
        .byte   (cmd_table_futils_cmds - cmd_table_fujifs_cmds) / 2 - 1

        .byte   "BOOT",      $8C, $08         ; <slot>/<dos name>
        .byte   "CD",        $87, $00         ; (<path>)
        .byte   "FS",        $95, $00         ; <path>
        .byte   "HOST",      $95, $00         ; <path>
        .byte   "DRIVE",     $80, $00
        .byte   "IN",        $8B, $08         ; (<slot>) <dos name>
        .byte   "LS",        $87, $00         ; (<path>)
        .byte   "LIST",      $87, $00         ; (<path>)
        .byte   "MOUNT",     $8A, $04         ; <slot> (<drive>)
        .byte   "UNMOUNT",   $83, $00         ; <drive>
        .byte   "OUT",       $8A, $00         ; <slot>
        .byte   "JSON",      $93, $00         ; <string>
        .byte   "NEW",       $88, $00         ; <dos name>
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

; OLD: cmdaddr2
cmd_table_utils_cmds:
        .word   cmd_utils_roms-1
        .word   not_cmd_utils-1

; OLD: cmdaddr22
cmd_table_fs_cmds:
        .word   cmd_fs_disc-1
        .word   cmd_fs_disc-1           ; DISK same as DISC
        .word   cmd_fs_fuji-1
        .word   not_cmd_fs-1

; OLD: cmdaddr3
cmd_table_help_cmds:
        .word   cmd_help_fuji-1
        .word   cmd_help_futils-1
        .word   cmd_help_utils-1
        .word   not_cmd_help-1

; OLD: cmdaddr4
cmd_table_futils_cmds:
        .word   cmd_fs_fboot-1
        .word   cmd_fs_fcd-1
        .word   cmd_fs_fhost-1
        .word   cmd_fs_fhost-1
        .word   cmd_fs_fdrive-1
        .word   cmd_fs_fin-1
        .word   cmd_fs_flist-1
        .word   cmd_fs_flist-1
        .word   cmd_fs_fmount-1
        .word   cmd_fs_funmount-1
        .word   cmd_fs_fout-1
        .word   cmd_fs_fjson-1
        .word   cmd_fs_fnew-1
        .word   not_cmd_futils-1

cmd_table_END:

parameter_table:
        .byte '<'|$80, "fsp>"                   ; 1
        .byte '<'|$80, "afsp>"                  ; 2
        .byte '<'|$80, "drive>"                 ; 3
        .byte '('|$80, "<drive>)"               ; 4
        .byte '('|$80, "<drive>)..."            ; 5
        .byte '('|$80, "<dir>)"                 ; 6
        .byte '('|$80, "<path>)"                ; 7
        .byte '<'|$80, "dos name>"              ; 8
        .byte '('|$80, "<dos name>)"            ; 9
        .byte '<'|$80, "slot>"                  ; A
        .byte '('|$80, "<slot>)"                ; B
        .byte '<'|$80, "slot> /"                ; C
        .byte '<'|$80, "title>"                 ; D
        .byte '<'|$80, "uri>"                   ; E
        .byte '<'|$80, "src> <dest>"            ; F
        .byte '<'|$80, "old fsp> <new fsp>"     ; 10
        .byte '<'|$80, "filter>"                ; 11
        .byte '4'|$80, "0/80"                   ; 12
        .byte '<'|$80, "string>"                ; 13
        .byte '('|$80, "L)"                     ; 14
        .byte '<'|$80, "path>"                  ; 15

        .byte $FF
