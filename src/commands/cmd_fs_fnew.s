; *FNEW - create a new SSD image in the current FHOST path

        .export  cmd_fs_fnew

        .importzp aws_tmp00
        .importzp cws_tmp2
        .importzp cws_tmp3

        .import err_no_host
        .import exit_user_ok
        .import fuji_channel_scratch
        .import fuji_create_disk
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_fs_uri_ptr
        .import get_fuji_host_uri_addr_to_aws_tmp00
        .import num_params
        .import param_get_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

err_fnew_syntax:
        jsr     report_error
        .byte   $CB
        .byte   "FNEW <name.ssd>", 0

err_fnew_create:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to create", 0

cmd_fs_fnew:
        lda     fuji_current_host_len
        bne     @have_host
        jmp     err_no_host

@have_host:
        jsr     num_params
        cmp     #$01
        bne     err_fnew_syntax

        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     fnew_build_full_uri

        lda     #$00                    ; flags: no overwrite
        jsr     fuji_create_disk
        cmp     #$00
        beq     err_fnew_create

        jmp     exit_user_ok

; Build full URI in PWS FS slot: host || filename, NUL, fuji_current_fs_len
fnew_build_full_uri:
        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        lda     fuji_current_host_len
        tax
        beq     @host_done
        ldy     #$00
@copy_host:
        lda     (aws_tmp00),y
        sta     (cws_tmp2),y
        iny
        dex
        bne     @copy_host

@host_done:
        lda     fuji_filename_len
        tax
        beq     @terminate

        lda     #$00
        sta     fuji_channel_scratch
@copy_name:
        ldy     fuji_channel_scratch
        lda     fuji_filename_buffer,y
        pha
        lda     fuji_current_host_len
        clc
        adc     fuji_channel_scratch
        tay
        pla
        sta     (cws_tmp2),y
        inc     fuji_channel_scratch
        dex
        bne     @copy_name

@terminate:
        lda     fuji_current_host_len
        clc
        adc     fuji_filename_len
        tay
        lda     #$00
        sta     (cws_tmp2),y
        lda     fuji_current_host_len
        clc
        adc     fuji_filename_len
        sta     fuji_current_fs_len
        rts
