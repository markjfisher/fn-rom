; *FHOST / *FFS — set or show canonical host URI (FileDevice ResolvePath)
        .export  cmd_fs_fhost

        ; exports for debug
        .export  fhost_copy_and_resolve

        .import  exit_user_ok
        .import  fuji_dir_path_ptr
        .import  fuji_host_uri_ptr
        .import  fuji_resolve_path
        .import  param_count
        .import  param_get_string
        .import  print_char
        .import  print_newline
        .import  print_string_ax
        .import  report_error

        .include "fujinet.inc"

        .segment "CODE"

;------------------------------------------------------------------------------
; uint8_t cmd_fs_fhost(void)
;------------------------------------------------------------------------------
cmd_fs_fhost:
        jsr     param_count
        bcs     @set_fhost

        jsr     fhost_show_current
        jmp     exit_user_ok

@set_fhost:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     fhost_copy_and_resolve
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

        jsr     fuji_host_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3
        lda     fuji_current_host_len
        tax
        jsr     print_cws_tmp2_x
        beq     @after_host             ; always

@host_none:
        jsr     print_none_str

@after_host:
        jsr     print_newline

        lda     #<str_fhost_path
        ldx     #>str_fhost_path
        jsr     print_string_ax

        lda     fuji_current_dir_len
        beq     @path_none

        jsr     fuji_dir_path_ptr
        sta     cws_tmp2
        stx     cws_tmp3
        lda     fuji_current_dir_len
        tax
        jsr     print_cws_tmp2_x
        beq     @after_path             ; always

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
; exits with Z=1
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
        jsr     fuji_host_uri_ptr               ; returns host_uri_ptr in a/x
        ; use aws_tmp02/03 locally as it is untouched by fuji_resolve_path, the only external function we use
        sta     aws_tmp02
        stx     aws_tmp03

        lda     fuji_filename_len
        sta     fuji_current_host_len

        lda     fuji_filename_len
        beq     @copy_done
        tax
        ldy     #$00
@copy:
        lda     fuji_filename_buffer,y
        sta     (aws_tmp02),y
        iny
        dex
        bne     @copy
@copy_done:
        ; ensure host ends with trailing "/"
        cmp     #'/'
        beq     @slash_present

        ; add the slash
        lda     #'/'
        sta     (aws_tmp02),y
        inc     fuji_current_host_len

@slash_present:
        ; call fujinet to resolve the given path
        jsr     fuji_resolve_path
        cmp     #$00
        beq     @resolve_err
        rts

@resolve_err:
        lda     #$00
        tay
        sta     (aws_tmp02),y
        sta     fuji_current_host_len
        sta     fuji_current_dir_len

        jsr     report_error
        .byte   $CB
        .byte   "Could not set host URI", 0

; STRINGS
        .segment "RODATA"

str_fhost_host:
        .byte   "HOST: ", $a0
str_fhost_path:
        .byte   "PATH: ", $a0
str_fhost_none:
        .byte   "(none)", $a0
