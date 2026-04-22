; *FHOST / *FFS — set or show canonical host URI (FileDevice ResolvePath)
        .export  _cmd_fs_fhost
        .export  _parse_fhost_params
        .export  _err_bad_uri

        .import  param_count
        .import  param_get_string

        .import  err_bad
        .import  report_error

        .import  print_char
        .import  print_newline
        .import  print_string_ax

        .import  exit_user_ok

        .import  _fuji_host_uri_ptr
        .import  _fuji_dir_path_ptr
        .import  _fuji_resolve_path

        .import  fuji_filename_buffer
        .import  fuji_filename_len
        .import  fuji_current_host_len
        .import  fuji_current_dir_len
        .import  fuji_channel_scratch

        .importzp cws_tmp2
        .importzp cws_tmp3

        .include "fujinet.inc"

        .segment "CODE"

;------------------------------------------------------------------------------
; uint8_t cmd_fs_fhost(void)
;------------------------------------------------------------------------------
_cmd_fs_fhost:
        jsr     _parse_fhost_params
        cmp     #$00
        beq     @show

        jsr     fhost_copy_and_resolve
        jmp     exit_user_ok

@show:
        jsr     fhost_show_current
        jmp     exit_user_ok

;------------------------------------------------------------------------------
; Show HOST (canonical URI in PWS) and PATH (suffix per host_len/dir_len)
;------------------------------------------------------------------------------
fhost_show_current:
        lda     #<str_fhost_host
        ldx     #>str_fhost_host
        jsr     print_string_ax

        lda     fuji_current_host_len
        beq     @host_none

        jsr     _fuji_host_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3
        lda     fuji_current_host_len
        tax
        jsr     print_cws_tmp2_x

        jmp     @after_host

@host_none:
        jsr     print_none_str

@after_host:
        jsr     print_newline

        lda     #<str_fhost_path
        ldx     #>str_fhost_path
        jsr     print_string_ax

        lda     fuji_current_dir_len
        beq     @path_none

        jsr     _fuji_dir_path_ptr
        sta     cws_tmp2
        stx     cws_tmp3
        lda     fuji_current_dir_len
        tax
        jsr     print_cws_tmp2_x

        jmp     @after_path

@path_none:
        jsr     print_none_str

@after_path:
        jmp     print_newline

;------------------------------------------------------------------------------
print_none_str:
        lda     #<str_fhost_none
        ldx     #>str_fhost_none
        jmp     print_string_ax

; Print X bytes from (cws_tmp2); X should be <= 80
print_cws_tmp2_x:
        ldy     #$00
        txa
        beq     @done
        sta     fuji_channel_scratch
@loop:
        lda     (cws_tmp2),y
        jsr     print_char
        iny
        dec     fuji_channel_scratch
        bne     @loop
@done:
        rts

;------------------------------------------------------------------------------
; Copy parsed URI into PWS host slot and ResolvePath; BRK path on failure
;------------------------------------------------------------------------------
fhost_copy_and_resolve:
        jsr     _fuji_host_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        lda     fuji_filename_len
        sta     fuji_current_host_len

        ldy     #$00
        lda     fuji_filename_len
        beq     @copy_done
        tax
@copy:
        lda     fuji_filename_buffer,y
        sta     (cws_tmp2),y
        iny
        dex
        bne     @copy
@copy_done:
        jsr     _fuji_resolve_path
        cmp     #$00
        beq     @resolve_err
        rts

@resolve_err:
        lda     #$00
        tay
        sta     (cws_tmp2),y
        sta     fuji_current_host_len
        sta     fuji_current_dir_len

        jsr     report_error
        .byte   $CB
        .byte   "Could not set host URI", 0

;------------------------------------------------------------------------------
; uint8_t parse_fhost_params(void)
; 0 params -> A=0; 1 param -> A = string length (same non-zero test as old C)
;------------------------------------------------------------------------------
_parse_fhost_params:
        jsr     param_count
        bcs     @read_string

        lda     #$00
        rts

@read_string:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        rts

_err_bad_uri:
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0

        .segment "RODATA"

str_fhost_host:
        .byte   "HOST: ", $a0
str_fhost_path:
        .byte   "PATH: ", $a0
str_fhost_none:
        .byte   "(none)", $a0
