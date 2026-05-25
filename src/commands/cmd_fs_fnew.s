; *FNEW - create a new SSD image in the current FHOST path

        .export  cmd_fs_fnew

        .importzp aws_tmp00
        .importzp cws_tmp2
        .importzp cws_tmp3

        .import err_no_host
        .import err_syntax
        .import exit_user_ok
        .import fuji_create_disk
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_fs_uri_ptr
        .import get_fuji_host_uri_addr_to_aws_tmp00
        .import param_count
        .import param_get_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fnew:
        lda     fuji_current_host_len
        bne     @have_host
        jmp     err_no_host

@have_host:
        jsr     param_count             ; 0-1, C=0 means we had no args
        bcs     one_arg
        jmp     err_syntax

one_arg:
        clc
        jsr     param_get_string
        sta     fuji_filename_len

; Build full URI in PWS FS slot: host || filename, NUL, fuji_current_fs_len
fnew_build_full_uri:
        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        ldy     #$00
@copy_host:
        cpy     fuji_current_host_len
        beq     @host_done
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        bne     @copy_host

@host_done:
        ldx     #$00

@copy_name:
        cpx     fuji_filename_len
        beq     @terminate
        lda     fuji_filename_buffer,x
        sta     (cws_tmp2),y
        iny
        inx
        bne     @copy_name

@terminate:
        lda     #$00
        sta     (cws_tmp2),y
        tya
        sta     fuji_current_fs_len

exit_fnew:
        lda     #$00                    ; flags: no overwrite
        jsr     fuji_create_disk
        cmp     #$00
        beq     err_fnew_create
        jmp     exit_user_ok

err_fnew_create:
        jsr     report_error
        .byte   $CB
        .byte   "FNEW err", 0
