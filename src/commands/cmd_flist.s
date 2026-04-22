        ; .export  cmd_fs_flist
        ; .export  cmd_fs_fls
        .export  _parse_flist_params
        .export  _err_bad_flist_path
        .export  _err_flist_failed
        .export  _err_no_host_flist

        .import  _cmd_fs_flist
        .import  err_bad
        .import  report_error
        .import  param_count
        .import  param_get_string
        .import  fuji_filename_len

        .include "fujinet.inc"

        .segment "CODE"

; cmd_fs_flist:
; cmd_fs_fls:
;         jmp     _cmd_fs_flist

; uint8_t parse_flist_params()
;
; FLIST/FLS supports 0 or 1 parameters:
;   0 params: list current host path, return 0
;   1 param:  read path into fuji_filename_buffer, return 1
;
; Returns: A = param count (0 or 1)
_parse_flist_params:
        jsr     param_count
        bcs     @read_string

        lda     #$00
        tax
        rts

@read_string:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        lda     #$01
        rts

_err_no_host_flist:
        jsr     report_error
        .byte   $CB
        .byte   "No host set", 0

_err_bad_flist_path:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0

_err_flist_failed:
        jsr     report_error
        .byte   $CB
        .byte   "Directory list failed", 0

