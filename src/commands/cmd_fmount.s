; *FMOUNT — bind BBC drive to persisted FujiNet mount slot (GetMount + disk mount)

        .export  cmd_fs_fmount

        .export  err_bad_disk_mount
        .export  err_failed_to_mount
        .export  mount_ok

        .import  err_bad_mount_slot
        .import  exit_user_ok
        .import  set_fuji_data_buffer_ptr
        .import  fuji_fs_uri_ptr
        .import  fuji_get_slot
        .import  fuji_mount_disk
        .import  param_count_a
        .import  param_get_num
        .import  param_optional_drive_no
        .import  report_error

        .include "fujinet.inc"

        .segment "CODE"


; Allow slot number to be 0-7
MAX_MOUNT_SLOT_COUNT := 8

; Allow drives 0-3
MAX_BBC_DRIVE  := 3


;------------------------------------------------------------------------------
; Main entry — same layout as cmd_fin.s (parse, FujiBus, exit_user_ok)
;------------------------------------------------------------------------------
cmd_fs_fmount:
        ; if cli args have 1 arg, set bbc_slot to default value
        ; if cli args have 2 args, set both from params
        ; otherwise fails with syntax error (no return)
        ;
        ; writes param 1 to fuji_disk_slot, and param 2 (or default) to current_drv

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
        bcc     @in_range
        jmp     err_bad_mount_slot

@in_range:
        sta     fuji_disk_slot

        ; do we have 2nd param?
        cpx     #$02
        bne     @done

        ; deal with optional drive
        jsr     param_optional_drive_no

@done:
        jsr     fuji_get_slot
        cmp     #$00
        bne     mount_ok

err_failed_to_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Err reading slot", 0

mount_ok:
        ; put fs_uri location in cws_tmp2/3, do it before set_fuji_data_buffer_ptr
        jsr     fuji_fs_uri_ptr
        sta     cws_tmp2
        stx     cws_tmp3

        ; set buffer_ptr/aws_tmp00/01 to PWS location
        jsr     set_fuji_data_buffer_ptr

        ; After FujiBus hdr + status [5],[6]: GetMount record is
        ; [7]=slot (echoes request; 0 for slot 0), [8]=flags (bit0=enabled),
        ; [9]=uri_len, [10..]=uri — matches SetMount tx layout at [6..]
        ldy     #$08
        lda     (buffer_ptr),y
        and     #$01
        bne     is_enabled
        ; fall through to error

        jsr     report_error
        .byte   $CB
        .byte   "Not enabled", 0

is_enabled:
        ldy     #$09
        lda     (buffer_ptr),y
        tax                     ; uri_len

        lda     #$00
        ldy     #$00
        sta     (cws_tmp2),y
        sta     cws_tmp6                ; used as a scratch value for following loop
        lda     #$0A
        sta     cws_tmp7                ; 10 above tmp6

        cpx     #$00
        beq     @len_done

        ; copy X bytes from buffer_ptr+10 to fs_uri
@copy_uri:
        ldy     cws_tmp7
        lda     (buffer_ptr),y
        ldy     cws_tmp6
        sta     (cws_tmp2),y
        inc     cws_tmp6
        inc     cws_tmp7
        dex
        bne     @copy_uri

@len_done:
        lda     cws_tmp6
        sta     fuji_current_fs_len

        lda     fuji_disk_slot
        sta     aws_tmp08

        jsr     fuji_mount_disk                         ; this uses "remember_xy_only" - can't rely on PLA to keep A set
        cmp     #$00
        beq     err_bad_disk_mount
        jmp     exit_user_ok

err_bad_disk_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to mount disk", 0
