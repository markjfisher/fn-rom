; *FMOUNT — bind BBC drive to persisted FujiNet mount slot (GetMount + disk mount)

        .export  _cmd_fs_fmount
        .export  _err_bad_disk_mount
        .export  _err_bad_mount_slot
        .export  _err_failed_to_mount
        .export  _err_not_enabled
        .export  _parse_fmount_params

        .import  err_bad
        .import  param_count_a
        .import  param_get_num
        .import  param_optional_drive_no
        .import  report_error

        .import  exit_user_ok
        .import  _fuji_data_buffer_ptr
        .import  _fuji_fs_uri_ptr

        .import  fuji_get_slot
        .import  fuji_mount_disk

        .import  fuji_channel_scratch
        .import  fuji_current_fs_len
        .import  fuji_disk_slot

        .importzp  cws_tmp2
        .importzp  cws_tmp3
        .importzp  aws_tmp08

        .include "fujinet.inc"

        .segment "CODE"


; Allow slot number to be 0-7
MAX_MOUNT_SLOT_COUNT := 8

; Allow drives 0-3
MAX_BBC_DRIVE  := 3

;------------------------------------------------------------------------------
; Main entry — same layout as cmd_fin.s (parse, FujiBus, exit_user_ok)
;------------------------------------------------------------------------------
_cmd_fs_fmount:
        jsr     _parse_fmount_params

        jsr     fuji_get_slot
        cmp     #$00
        beq     @get_failed

        jsr     _fuji_data_buffer_ptr
        sta     aws_tmp00
        stx     aws_tmp01

        ; After FujiBus hdr + status [5],[6]: GetMount record is
        ; [7]=slot (echoes request; 0 for slot 0), [8]=flags (bit0=enabled),
        ; [9]=uri_len, [10..]=uri — matches SetMount tx layout at [6..]
        ldy     #$08
        lda     (aws_tmp00),y
        and     #$01
        bne     @enabled
        jmp     _err_not_enabled

@enabled:
        ; _fuji_fs_uri_ptr returns pointer in A/X — do not hold uri_len in X across it
        ldy     #$09
        lda     (aws_tmp00),y
        pha                     ; uri_len (stack)

        jsr     _fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        lda     #$00
        ldy     #$00
        sta     (cws_tmp2),y

        lda     #$00
        sta     fuji_channel_scratch

        pla
        tax                     ; uri_len back in X

        beq     @len_done

@copy_uri:
        lda     fuji_channel_scratch
        clc
        adc     #$0A
        tay
        lda     (aws_tmp00),y
        pha
        ldy     fuji_channel_scratch
        pla
        sta     (cws_tmp2),y
        inc     fuji_channel_scratch
        dex
        bne     @copy_uri

@len_done:
        lda     fuji_channel_scratch
        sta     fuji_current_fs_len

        lda     fuji_disk_slot
        sta     aws_tmp08

        jsr     fuji_mount_disk
        cmp     #$00
        beq     @mount_failed
        jmp     exit_user_ok

@get_failed:
        jmp     _err_failed_to_mount

@mount_failed:
        jmp     _err_bad_disk_mount

; void parse_params()
;
; if cli args have 1 arg, set bbc_slot to default value
; if cli args have 2 args, set both from params
; otherwise fails with syntax error (no return)
;
; writes param 1 to fuji_disk_slot, and param 2 (or default) to current_drv

_parse_fmount_params:
        ; Count parameters first. FMOUNT supports 1 or 2 parameters.
        lda     #$80                    ; allows 1-2 parameters
        jsr     param_count_a           ; this causes an error if we don't have 1-2 params, but preserves Y
        ; C = 0 indicates we had 1 param, C = 1 indicates we had 2 params

        ldx     #$01
        bcc     @only_mount_slot
        inx
@only_mount_slot:
        ; X is preserved though param_get_num so we retain the number of params in X
        ; Read and the mandatory FujiNet mount slot index. Y is already the correct location after param_count_a
        jsr     param_get_num           ; FujiNet mount slot index 0-7, this errors if the value is not between 0-9

        cmp     #MAX_MOUNT_SLOT_COUNT
        bcs     _err_bad_mount_slot

        sta     fuji_disk_slot

        ; do we have 2nd param?
        cpx     #$02
        bne     @done

        ; use existing function to deal with optional drive
        jsr     param_optional_drive_no

@done:
        rts


_err_bad_mount_slot:
        ; this terminates command because the byte after the string is 0
        jsr     err_bad
        .byte   $CB                     ; TODO sort out what error codes we want to return
        .byte   "mount slot", 0         ; terminate after message

_err_failed_to_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to read mount slot", 0

_err_not_enabled:
        jsr     report_error
        .byte   $CB
        .byte   "Mount point not enabled", 0

_err_bad_disk_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to mount disk", 0
