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
        .import  set_user_flag_x

        .importzp  ptr1

        .include "fujinet.inc"

        .segment "CODE"


; Allow slot number to be 0-7
; I'm not sure if we want to force a limit in fujinet-nio for number of mounts.
; There's a limit on the reading params in get_param_num, so that would have
; to be fixed if we wanted to support any number of mount entries.
MAX_MOUNT_SLOT := 7

; Allow drives 0-3
MAX_BBC_DRIVE  := 3

; void parse_params()
;
; if cli args have 1 arg, set bbc_slot to default value
; if cli args have 2 args, set both from params
; otherwise fails with syntax error (no return)
;
; writes to param 1 to fuji_disk_slot, and param 2 (or default) to current_drv

_parse_fmount_params:
        ; Count parameters first. FMOUNT supports 1 or 2 parameters.
        ldy     fuji_cmd_offset_y       ; ensure the cmd line Y index is correct
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
        sty     fuji_cmd_offset_y       ; save the command position in case we have more params

        cmp     #MAX_MOUNT_SLOT
        bcs     _err_bad_mount_slot

        sta     fuji_disk_slot

        ; do we have 2nd param?
        cpx     #$02
        bne     @done

        ; use existing function to deal with optional drive
        ldy     fuji_cmd_offset_y
        jsr     param_optional_drive_no

@done:
        ldx     #$00
        jmp     set_user_flag_x


_err_bad_mount_slot:
        ; this terminates command because the byte after the string is 0
        jsr     err_bad
        .byte   $CB                     ; TODO sort out what error codes we want to return
        .byte   "mount slot", 0         ; terminate after message

_err_failed_to_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to set mount config", 0

_err_not_enabled:
        jsr     report_error
        .byte   $CB
        .byte   "Mount point not enabled", 0

_err_bad_disk_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to mount disk", 0
