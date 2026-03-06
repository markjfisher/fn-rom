        .export cmd_fs_fcd

        .import err_bad
        .import fn_file_resolve_path
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fcd:
        jsr     num_params
        cmp     #$00
        beq     @print_current_path
        cmp     #$01
        bne     @bad

        jsr     param_get_string
        bcc     @bad_path

        lda     #<fuji_current_fs_uri
        sta     aws_tmp00
        lda     #>fuji_current_fs_uri
        sta     aws_tmp01
        lda     fuji_current_fs_len
        sta     aws_tmp02
        lda     #<fuji_filename_buffer
        sta     aws_tmp03
        lda     #>fuji_filename_buffer
        sta     aws_tmp04
        sta     aws_tmp04
        lda     #$00
        sta     aws_tmp05
        jsr     fn_file_resolve_path
        bcs     @bad_path

        ldx     #$00
        jmp     set_user_flag_x

@print_current_path:
        ldy     #$00
@loop:
        lda     fuji_current_dir_path,y
        beq     @done
        jsr     print_char
        iny
        bne     @loop
@done:
        jmp     print_newline

@bad_path:
        jsr     err_bad
        .byte   $CB
        .byte   "directory", 0

@bad:
        jsr     err_bad
        .byte   $CB
        .byte   "path", 0
