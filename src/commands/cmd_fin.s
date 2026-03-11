        .export  _parse_fin_params
        .export  _err_no_host
        .export  _err_bad_filename
        .export  _err_set_mount_failed

        .import  param_count_a
        .import  err_bad
        .import  report_error
        .import  param_get_num
        .import  param_get_string
        .import  fuji_filename_buffer
        .import  fuji_filename_len
        .import  exit_user_ok
        .import  fuji_filename_len

        .import  _err_bad_mount_slot

        .include "fujinet.inc"

        .segment "CODE"


; Allow slot number to0-7
MAX_MOUNT_SLOT := 7

; void parse_fin_params()
;
; if cli args have 1 arg: filename only, slot = default (0)
; if cli args have 2 args: slot and filename
; otherwise fails with syntax error (no return)
;
; Writes: 
;   fuji_disk_slot = mount slot
;   fuji_filename_buffer = filename
;   fuji_filename_len = filename length (returned by param_get_string)

_parse_fin_params:
        ; Count parameters first. FIN supports 1 or 2 parameters.
        ldy     fuji_cmd_offset_y       ; ensure the cmd line Y index is correct
        lda     #$80                    ; allows 1-2 parameters
        jsr     param_count_a           ; this causes an error if we don't have 1-2 params, but preserves Y
        ; C = 0 indicates we had 1 param, C = 1 indicates we had 2 params

        ; Do we have a slot number?
        bcc     @read_filename          ; C=0, only filename provided

        ; We have 2 params - read slot number first
        jsr     param_get_num           ; FujiNet mount slot index 0-7
        sty     fuji_cmd_offset_y       ; save the command position for next param

        cmp     #MAX_MOUNT_SLOT+1
        bcc     @ok_slot

        jmp     _err_bad_mount_slot

@ok_slot:
        sta     fuji_disk_slot
        ; ... fallthrough

@read_filename:
        clc                             ; GSINIT param, string terminated by one of: CR, space or 2nd quotation mark - no spaces in file names as it would mess up the param count anyway
        jsr     param_get_string        ; reads filename into fuji_filename_buffer, returns length in A
        
        ; Store filename length
        sta     fuji_filename_len
        
        ; End parsing
        rts

_err_no_host:
        jsr     report_error
        .byte   $CB
        .byte   "No host set", 0

_err_bad_filename:
        jsr     err_bad
        .byte   $CB
        .byte   "filename", 0

_err_set_mount_failed:
        jsr     report_error
        .byte   $CB
        .byte   "Set Mount error", 0
