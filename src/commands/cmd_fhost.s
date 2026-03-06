        .export cmd_fs_fhost
        .export fhost_show_current_fs
        .export fhost_set_current_fs

        .import err_bad
        .import err_syntax
        .import exit_user_ok
        .import fn_file_resolve_path
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import print_space
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fhost - Handle *FHOST / *FFS command
; Syntax:
;   *FHOST            ; show current filesystem URI and current path
;   *FHOST <uri>      ; set current filesystem URI and reset current path
;   *FFS <uri>        ; alias of *FHOST
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fhost:
        jsr     num_params
        cmp     #$00
        beq     fhost_show_current_fs
        cmp     #$01
        beq     fhost_set_current_fs
        jmp     err_syntax

fhost_show_current_fs:
        jsr     print_newline
        jsr     print_string
        .byte   "FS", 0
        jsr     print_space

        ldx     fuji_current_fs_len
        beq     @print_none

        ldy     #$00
@print_fs_loop:
        lda     fuji_current_fs_uri,y
        beq     @print_path
        jsr     print_char
        iny
        bne     @print_fs_loop

@print_path:
        jsr     print_newline
        jsr     print_string
        .byte   "DIR", 0
        jsr     print_space

        ldx     fuji_current_dir_len
        beq     @print_root

        ldy     #$00
@print_dir_loop:
        lda     fuji_current_dir_path,y
        beq     @done
        jsr     print_char
        iny
        bne     @print_dir_loop

@done:
        jmp     print_newline

@print_none:
        jsr     print_string
        .byte   "(none)", 0
        jmp     @print_path

@print_root:
        lda     #'/'
        jsr     print_char
        jmp     @done

fhost_set_current_fs:
        jsr     param_get_string
        bcc     err_bad_uri

        sta     fuji_current_fs_len

        ldy     #$00
@copy_uri_loop:
        lda     fuji_filename_buffer,y
        sta     fuji_current_fs_uri,y
        beq     @copy_done
        iny
        cpy     fuji_current_fs_len
        bcc     @copy_uri_loop

@copy_done:
        lda     #<fuji_current_fs_uri
        sta     aws_tmp00
        lda     #>fuji_current_fs_uri
        sta     aws_tmp01
        lda     fuji_current_fs_len
        sta     aws_tmp02
        lda     #<fuji_buf_1072
        sta     aws_tmp03
        lda     #>fuji_buf_1072
        sta     aws_tmp04
        lda     #$00
        sta     aws_tmp05

        jsr     fn_file_resolve_path
        bcc     @resolved_ok

        lda     #'/'
        sta     fuji_current_dir_path
        lda     #$00
        sta     fuji_current_dir_path+1
        lda     #$01
        sta     fuji_current_dir_len

@resolved_ok:

        jmp     exit_user_ok

err_bad_uri:
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0
