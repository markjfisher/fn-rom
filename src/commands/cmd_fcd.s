        .export  cmd_fs_fcd

        .export  fcd_commit_resolved_path
        .export  fcd_print_current_path
        .export  fcd_print_cws_tmp2_x

        .import  err_bad
        .import  err_no_host
        .import  exit_user_ok
        .import  flist_resolve_target
        .import  fuji_dir_path_ptr
        .import  get_fuji_fs_uri_addr_to_aws_tmp00
        .import  get_fuji_host_uri_addr_to_aws_tmp00
        .import  param_count
        .import  param_get_string
        .import  print_char
        .import  print_newline
        .import  set_fuji_data_buffer_ptr

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
        bcs     fcd_set_path

        jsr     fcd_print_current_path
        jmp     exit_user_ok

fcd_set_path:
        lda     fuji_current_host_len
        bne     :+
        jmp     err_no_host
:
        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     set_fuji_data_buffer_ptr
        jsr     flist_resolve_target
        bcc     :+
        jmp     fcd_err_bad_directory
:
        jsr     fcd_commit_resolved_path
        jsr     fcd_print_current_path
        jmp     exit_user_ok

fcd_err_bad_directory:
        jsr     err_bad
        .byte   $CB
        .byte   "directory", 0

;------------------------------------------------------------------------------
; Commit the resolved FS URI from flist_resolve_target into host state.
; buffer_ptr still addresses the ResolvePath response packet.
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
@copy_host:
        cpy     fuji_current_host_len
        beq     @host_copied
        lda     (aws_tmp06),y
        sta     (aws_tmp00),y
        iny
        bne     @copy_host

@host_copied:
        cpy     #FUJI_FS_URI_BUFFER_SIZE
        bcs     @path_len_ptr
        lda     #$00
        sta     (aws_tmp00),y

@path_len_ptr:
        lda     buffer_ptr
        clc
        adc     #$0D
        sta     cws_tmp2
        lda     buffer_ptr+1
        adc     #$00
        sta     cws_tmp3

        lda     cws_tmp2
        clc
        adc     fuji_current_host_len
        sta     cws_tmp2
        lda     cws_tmp3
        adc     #$00
        sta     cws_tmp3

        ldy     #$00
        lda     (cws_tmp2),y
        sta     cws_tmp1
        iny
        lda     (cws_tmp2),y
        bne     @clear_dir_len

        lda     cws_tmp1
        cmp     fuji_current_host_len
        bcc     @store_dir_len
        beq     @store_dir_len

@clear_dir_len:
        lda     #$00

@store_dir_len:
        sta     fuji_current_dir_len
        rts

;------------------------------------------------------------------------------
; Print current human-friendly path only.
;------------------------------------------------------------------------------
fcd_print_current_path:
        lda     fuji_current_dir_len
        beq     @done

        jsr     fuji_dir_path_ptr
        sta     cws_tmp2
        stx     cws_tmp3
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
