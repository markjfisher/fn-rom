        .export  _parse_fhost_params
        .export  _err_bad_uri
        .export  _err_set_uri

        .import  param_count
        .import  param_count_a
        .import  param_get_string
        .import  err_bad
        .import  report_error
        .import  fuji_filename_buffer
        .import  fuji_filename_len
        .import  fuji_error_flag
        .import  fuji_cmd_offset_y

        .include "fujinet.inc"

        .segment "CODE"


; uint8_t parse_fhost_params()
;
; FHOST supports 0 or 1 parameters:
;   0 params: no action needed, return 0
;   1 param:  read string into fuji_filename_buffer, return 1
;
; Returns: A = param count (0 or 1)

_parse_fhost_params:
        ; Count parameters first. FHOST supports 0 or 1 parameters.
        ldy     fuji_cmd_offset_y       ; ensure the cmd line Y index is correct
        jsr     param_count             ; C=0 means 0 params, C=1 means 1 param

        ; Determine param count from carry flag
        bcs     @read_string

        lda     #$00            ; this may not be needed, with param_count, A should be 0 on exit
        tax
        rts

@read_string:
        ; We have 1 param - read the string
        clc                             ; string terminated by CR, space or quote
        jsr     param_get_string        ; reads into fuji_filename_buffer, returns length in A

        ; Store length
        sta     fuji_filename_len

        rts


_err_bad_uri:
        ; Standard ROM "Bad uri" error path.
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0

_err_set_uri:
        ; Standard ROM "Bad uri" error path.
        jsr     report_error
        .byte   $CB
        .byte   "Could not set host URI", 0
