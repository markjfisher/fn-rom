; *FIN — persist URI into FujiNet mount slot (host + filename → SetMount)

        .export  _cmd_fs_fin
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
        .import  fuji_disk_slot
        .import  fuji_current_host_len
        .import  fuji_current_fs_len

        .import  exit_user_ok

        .import  _fuji_fs_uri_ptr
        .import  get_fuji_host_uri_addr_to_aws_tmp6
        .import  fuji_set_slot

        .import  _err_bad_mount_slot

        .importzp cws_tmp2
        .importzp cws_tmp3
        .importzp aws_tmp06
        .import  fuji_channel_scratch

        .include "fujinet.inc"

        .segment "CODE"

MAX_MOUNT_SLOT := 7

;------------------------------------------------------------------------------
; uint8_t cmd_fs_fin(void)
;------------------------------------------------------------------------------
_cmd_fs_fin:
        jsr     _parse_fin_params

        lda     fuji_current_host_len
        bne     @have_host
        jmp     _err_no_host

@have_host:
        jsr     fin_build_full_uri

        jsr     fuji_set_slot
        cmp     #$00
        bne     @set_ok
        jmp     _err_set_mount_failed

@set_ok:
        jmp     exit_user_ok

;------------------------------------------------------------------------------
; Build full URI in PWS FS slot: host || filename, NUL, fuji_current_fs_len
;------------------------------------------------------------------------------
fin_build_full_uri:
        jsr     _fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        jsr     get_fuji_host_uri_addr_to_aws_tmp6

        lda     fuji_current_host_len
        tax
        beq     @host_done
        ldy     #$00
@copy_host:
        lda     (aws_tmp06),y
        sta     (cws_tmp2),y
        iny
        dex
        bne     @copy_host
        ; Y = host_len
@host_done:

        lda     fuji_filename_len
        tax
        beq     @terminate

        lda     #$00
        sta     fuji_channel_scratch
@copy_fn:
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
        bne     @copy_fn

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

;------------------------------------------------------------------------------
; void parse_fin_params(void)
; 1 arg: filename only → fuji_disk_slot = 0
; 2 args: slot then filename (slot 0–7)
;------------------------------------------------------------------------------
_parse_fin_params:
        lda     #$80
        jsr     param_count_a

        bcc     @one_param_only

        jsr     param_get_num

        cmp     #MAX_MOUNT_SLOT+1
        bcc     @ok_slot

        jmp     _err_bad_mount_slot

@ok_slot:
        sta     fuji_disk_slot
        jmp     @read_filename

@one_param_only:
        lda     #$00
        sta     fuji_disk_slot

@read_filename:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
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
