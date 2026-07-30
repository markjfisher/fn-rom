; Command tables for FujiNet ROM
;
; Each command is declared with the cmd_entry macro (see src/inc/macros.inc),
; which emits the matched text + parameter bytes into a per-group CMDSTR_<grp>
; segment and the handler address into the parallel CMDADR_<grp> segment. The
; matcher (service09.s) walks a group's CMDSTR segment to a $00 terminator and
; dispatches through CMDADR by entry position, so a command is present in the
; ROM iff its object module is linked — there is no inline .if in the tables.
; See docs/BOOT_DISK_PLAN.md §5.3.
;
; Groups: FUJIFS (DFS file-system commands), FUTILS ("F"-prefixed FujiNet
; commands), UTILS (non-FS), FS (filing-system selection), HELP (*HELP topics).

        ; Group start markers — the matcher/help printer index these by group id.
        ; A group's commands may be extended by other modules appending entries
        ; into its CMDSTR_/CMDADR_ segment (e.g. cmd_free_map.s -> FUJIFS), so the
        ; start label is always the first byte of the group.
        .export cmd_str_fujifs
        .export cmd_str_futils
        .export cmd_str_utils
        .export cmd_str_fs
        .export cmd_str_help
        .export cmd_adr_fujifs
        .export cmd_adr_futils
        .export cmd_adr_utils
        .export cmd_adr_fs
        .export cmd_adr_help

        .export cmd_table_info
        .export parameter_table

        ; Resident command handlers only. Transient management/informational
        ; commands self-register into CMDSTR_<grp>_EXT from their src/utils/
        ; boot-disk utility modules, and *FJSON from src/net/ — so they are absent here
        ; and vanish from the table when their module is not linked.
        .import cmd_fs_close
        .import cmd_fs_delete
        .import cmd_fs_dir
        .import cmd_fs_disc
        .import cmd_fs_drive
        .import cmd_fs_enable
        .import cmd_fs_ex
        .import cmd_fs_fboot
        .import cmd_fs_fdrive
        .import cmd_fs_fhost
        .import cmd_fs_fin
        .import cmd_fs_fmount
        .import cmd_fs_fuji
        .import cmd_fs_info
        .import cmd_fs_lib
        .import cmd_help_fuji
        .import cmd_help_futils

        .include "fujinet.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND TABLE - FujiNet file system commands, help = "*HELP FUJI"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "CMDADR_FUJIFS"
cmd_adr_fujifs:
        .segment "CMDSTR_FUJIFS"
cmd_str_fujifs:
        cmd_entry "FUJIFS", "CLOSE",   $00, $00, cmd_fs_close
        cmd_entry "FUJIFS", "DELETE",  $01, $00, cmd_fs_delete   ; <fsp>
        cmd_entry "FUJIFS", "DIR",     $06, $00, cmd_fs_dir      ; (<dir>)
        cmd_entry "FUJIFS", "DRIVE",   $03, $00, cmd_fs_drive    ; <drive>
        cmd_entry "FUJIFS", "ENABLE",  $00, $00, cmd_fs_enable
        cmd_entry "FUJIFS", "EX",      $06, $00, cmd_fs_ex       ; (<dir>)
; cmd_table_info marks the *INFO entry so cmd_info.s can print its help line.
cmd_table_info:
        cmd_entry "FUJIFS", "INFO",    $02, $00, cmd_fs_info     ; <afsp>
        cmd_entry "FUJIFS", "LIB",     $06, $00, cmd_fs_lib      ; (<dir>)
        ; Transient boot-disk utilities self-register into CMDSTR_FUJIFS_EXT from
        ; src/utils/: ACCESS, COPY, DESTROY, FORM, RENAME, TITLE, WIPE,
        ; and FREE/MAP (cmd_free_map.s).
        .segment "CMDSTR_FUJIFS_T"
        .byte   $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND TABLE - "F"-prefixed FujiNet commands, help = "*HELP FUTILS"
; Stored without the leading "F" (the matcher consumes it; help re-adds it).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "CMDADR_FUTILS"
cmd_adr_futils:
        .segment "CMDSTR_FUTILS"
cmd_str_futils:
        cmd_entry "FUTILS", "FS",      $15, $00, cmd_fs_fhost
        cmd_entry "FUTILS", "BOOT",    $04, $00, cmd_fs_fboot
        cmd_entry "FUTILS", "DRIVE",   $00, $00, cmd_fs_fdrive
        cmd_entry "FUTILS", "HOST",    $15, $00, cmd_fs_fhost
        cmd_entry "FUTILS", "IN",      $0B, $08, cmd_fs_fin      ; (<slot>) <dos name>
        cmd_entry "FUTILS", "MOUNT",   $0A, $04, cmd_fs_fmount   ; <slot> (<drive>)
        ; Transient boot-disk utilities self-register into CMDSTR_FUTILS_EXT from
        ; src/utils/: CD, LS, LIST, UMOUNT, OUT, NEW. *FJSON from src/net/.
        .segment "CMDSTR_FUTILS_T"
        .byte   $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND TABLE - Utils (non-FS) commands, help = "*HELP UTILS"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "CMDADR_UTILS"
cmd_adr_utils:
        .segment "CMDSTR_UTILS"
cmd_str_utils:
        .segment "CMDSTR_UTILS_T"
        .byte   $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND TABLE - Filing-system selection (no help topic)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "CMDADR_FS"
cmd_adr_fs:
        .segment "CMDSTR_FS"
cmd_str_fs:
        cmd_entry "FS", "DISC",        $00, $00, cmd_fs_disc
        cmd_entry "FS", "DISK",        $00, $00, cmd_fs_disc      ; DISK same as DISC
        cmd_entry "FS", "FUJI",        $00, $00, cmd_fs_fuji
        .segment "CMDSTR_FS_T"
        .byte   $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; COMMAND TABLE - *HELP topics, help = "*HELP"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "CMDADR_HELP"
cmd_adr_help:
        .segment "CMDSTR_HELP"
cmd_str_help:
        cmd_entry "HELP", "FUJI",      $00, $00, cmd_help_fuji
        cmd_entry "HELP", "FUTILS",    $00, $00, cmd_help_futils
        .segment "CMDSTR_HELP_T"
        .byte   $00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PARAMETER STRINGS (shared by the help printer; indexed by param slot)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        .segment "RODATA"
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
        .byte '('|$80, "<host>|LIST|n|n D)"     ; 15
        .byte '('|$80, "<handle> <string>)"     ; 16

        .byte $FF
