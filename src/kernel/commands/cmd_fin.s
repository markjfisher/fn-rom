; *FIN — persist URI/path into FujiNet mount slot (FujiNet resolves relative paths)
; Default persisted policy is AUTO; live mount behavior is chosen by *FMOUNT.

        .export  cmd_fs_fin

        .export  err_no_host
        .export  err_bad_mount_slot

        .importzp aws_tmp00
        .importzp cws_tmp2
        .importzp cws_tmp3

        .import err_bad
        .import exit_user_ok
        .import fuji_channel_scratch
        .import fuji_current_fs_len
        .import fuji_disk_slot
        .import fuji_filename_buffer
        .import fuji_filename_len
        .import fuji_fs_uri_ptr
        .import fuji_set_slot
        .import param_count_a
        .import param_get_num
        .import param_get_string
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

MAX_MOUNT_SLOT := 7

;------------------------------------------------------------------------------
; uint8_t cmd_fs_fin(void)
;------------------------------------------------------------------------------
cmd_fs_fin:
        ; parse parameters
        lda     #$80
        jsr     param_count_a
        bcc     @one_param_only

        jsr     param_get_num
        cmp     #MAX_MOUNT_SLOT+1
        bcs     err_bad_mount_slot

@ok_slot:
        sta     fuji_disk_slot
        bcc     @read_filename

@one_param_only:
        lda     #$00
        sta     fuji_disk_slot

@read_filename:
        clc
        jsr     param_get_string
        sta     fuji_filename_len

        jsr     fin_build_full_uri
        jsr     fuji_set_slot
        cmp     #$00
        bne     @set_ok

        jsr     report_error
        .byte   $CB
        .byte   "mount", 0

@set_ok:
        jmp     exit_user_ok


err_bad_mount_slot:
        ; this terminates command because the byte after the string is 0
        jsr     err_bad
        .byte   $CB                     ; TODO sort out what error codes we want to return
        .byte   "mount slot", 0         ; terminate after message
;------------------------------------------------------------------------------
err_no_host:
        jsr     report_error
        .byte   $CB
        .byte   "No host", 0

; Copy user path/URI into PWS FS slot, NUL, fuji_current_fs_len.
;------------------------------------------------------------------------------
fin_build_full_uri:
        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        ldy     #$00
        lda     fuji_filename_len
        tax
        beq     @terminate

@copy_fn:
        lda     fuji_filename_buffer,y
        sta     (cws_tmp2),y
        iny
        dex
        bne     @copy_fn

@terminate:
        lda     #$00
        sta     (cws_tmp2),y
        lda     fuji_filename_len
        sta     fuji_current_fs_len
        rts

;------------------------------------------------------------------------------
; void parse_fin_params(void)
; 1 arg: filename only → fuji_disk_slot = 0
; 2 args: slot then filename (slot 0–7)
;------------------------------------------------------------------------------
parse_fin_params:
        lda     #$80
        jsr     param_count_a

        bcc     @one_param_only

        jsr     param_get_num

        cmp     #MAX_MOUNT_SLOT+1
        bcc     @ok_slot

        bcs     err_bad_mount_slot

@ok_slot:
        sta     fuji_disk_slot
        bcc     @read_filename

@one_param_only:
        lda     #$00
        sta     fuji_disk_slot

@read_filename:
        clc
        jsr     param_get_string
        sta     fuji_filename_len
        rts
