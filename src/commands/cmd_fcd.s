        .export  cmd_fs_fcd

        .export  fcd_commit_resolved_path
        .export  fcd_print_current_path
        .export  fcd_print_cws_tmp2_x

        .importzp aws_tmp00
        .importzp aws_tmp01
        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp cws_tmp2
        .importzp cws_tmp3

        .import err_no_host
        .import exit_user_ok
        .import fhost_ensure_host_trailing_slash
        .import flist_resolve_target
        .import fuji_channel_scratch
        .import fuji_current_dir_len
        .import fuji_current_fs_len
        .import fuji_current_host_len
        .import fuji_filename_len
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import get_fuji_host_uri_addr_to_aws_tmp00
        .import param_count
        .import param_get_string
        .import print_char
        .import print_newline
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

;------------------------------------------------------------------------------
; cmd_fs_fcd - Handle *FCD command
;
; Supported forms:
;   *FCD
;       Print the current human-friendly path only.
;
;   *FCD <path>
;       Resolve <path> relative to the current canonical URI and, if accepted
;       by FujiNet-NIO as a valid directory target, update the ROM's stored
;       current URI and display path state.
;------------------------------------------------------------------------------
cmd_fs_fcd:
        jsr     param_count
        bcc     fcd_show_current

fcd_set_path:
        lda     fuji_current_host_len
        bne     :+
        jmp     err_no_host
:       
        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     flist_resolve_target
        bcc     fcd_resolved_ok

        jsr     report_error
        .byte   $CB
        .byte   "Bad string", 0

fcd_resolved_ok:
        jsr     fcd_commit_resolved_path
        jsr     fcd_print_current_path
        jmp     exit_user_ok

fcd_show_current:
        jsr     fcd_print_current_path
        jmp     exit_user_ok

;------------------------------------------------------------------------------
; Copy the resolved URI from working FS storage into the canonical host buffer.
; This keeps one authoritative current URI for FHOST/FCD/FLS.
;------------------------------------------------------------------------------
fcd_commit_resolved_path:
        jsr     get_fuji_fs_uri_addr_to_aws_tmp00
        lda     aws_tmp00
        sta     aws_tmp06
        lda     aws_tmp01
        sta     aws_tmp07

        jsr     get_fuji_host_uri_addr_to_aws_tmp00

        lda     fuji_current_fs_len
        sta     fuji_current_host_len

        ldy     #$00
@copy_uri:
        cpy     fuji_current_host_len
        beq     @nul_term
        lda     (aws_tmp06),y
        sta     (aws_tmp00),y
        iny
        bne     @copy_uri

@nul_term:
        cpy     #FUJI_HOST_URI_BUFFER_SIZE
        bcs     @done
        lda     #$00
        sta     (aws_tmp00),y
@done:
        jsr     fhost_ensure_host_trailing_slash
        rts

;------------------------------------------------------------------------------
; Print current human-friendly path only.
;------------------------------------------------------------------------------
fcd_print_current_path:
        lda     fuji_current_dir_len
        beq     @done

        jsr     get_fuji_host_uri_addr_to_aws_tmp00
        lda     fuji_current_host_len
        sec
        sbc     fuji_current_dir_len
        bcs     @suffix_off_ok
        lda     #$00
@suffix_off_ok:
        clc
        adc     aws_tmp00
        sta     cws_tmp2
        lda     aws_tmp01
        adc     #$00
        sta     cws_tmp3

        lda     fuji_current_dir_len
        tax
        jsr     fcd_print_cws_tmp2_x

@done:
        jmp     print_newline

; Print X bytes from (cws_tmp2). X should be <= 80.
fcd_print_cws_tmp2_x:
        ldy     #$00
        txa
        beq     @print_done
        sta     fuji_channel_scratch
@print_loop:
        lda     (cws_tmp2),y
        jsr     print_char
        iny
        dec     fuji_channel_scratch
        bne     @print_loop
@print_done:
        rts
