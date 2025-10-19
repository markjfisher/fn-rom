; *EX command implementation
; Translated from MMFS fscv9_starEX and CMD_EX (lines 642-657)

        .export cmd_fs_ex
        .export fscv9_star_ex

        .import GSINIT_A
        .import cmd_info_loop
        .import get_cat_entry
        .import parameter_afsp
        .import rdafsp_padall
        .import read_dir_drv_parameters2
        .import set_curdir_drv_to_defaults
        .import set_text_pointer_yx

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; fscv9_star_ex - FSCV entry point for *EX
; Translated from MMFS fscv9_starEX (line 642)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv9_star_ex:
        ; Set text pointer from Y,X
        jsr     set_text_pointer_yx
        ; Fall through to cmd_fs_ex

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_ex - Handle *EX command
; Syntax: *EX (<dir>)
; Translated from MMFS CMD_EX (lines 644-657)
; Shows file info with wildcard support, defaults to "*" if no parameter
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_ex:
        jsr     set_curdir_drv_to_defaults ; Set default directory and drive
        jsr     GSINIT_A                ; Check if string is null
        beq     @cmd_ex_nullstr         ; If null string, use "*"
        jsr     read_dir_drv_parameters2 ; Get directory/drive parameters
@cmd_ex_nullstr:
        lda     #'*'                    ; Default to wildcard "*"
        sta     fuji_filename_buffer    ; Store at start of filename buffer
        jsr     rdafsp_padall           ; Pad rest of filename with spaces
        jsr     parameter_afsp          ; Set up wildcard parameters
        jsr     get_cat_entry           ; Get next catalog entry
        jmp     cmd_info_loop          ; Loop if more entries
