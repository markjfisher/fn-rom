        .export  _parse_fmount_params
        .export  _err_bad_mount_slot
        .export  _err_failed_to_mount
        .export  _err_not_enabled

        .import  param_count_a
        .import  err_bad
        .import  report_error
        .import  param_get_num
        .import  param_optional_drive_no
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
        .byte   "Failed to mount", 0

_err_not_enabled:
        jsr     report_error
        .byte   $CB
        .byte   "Mount point not enabled", 0

        ; Validate that the selected persisted FujiNet slot is populated and
        ; enabled before updating the BBC-side bridge mapping.
;         jsr     fuji_get_mount_slot
;         bcs     bad_mount_slot
;         ldy     #FN_HEADER_SIZE+1
;         lda     _fuji_rx_buffer,y
;         and     #$01
;         beq     bad_mount_slot
;         iny
;         lda     _fuji_rx_buffer,y
;         beq     bad_mount_slot

;         ; Read optional BBC drive number, or fall back to the current/default
;         ; drive if the user omitted it.
;         jsr     param_drive_or_default  ; optional BBC drive number
;         sta     current_drv

;         ; Build the live DiskDevice mount request from the validated persisted URI
;         ; so FMOUNT immediately affects the active runtime state as well as the
;         ; ROM-side bridge table.
;         ldy     #FN_HEADER_SIZE+2
;         lda     _fuji_rx_buffer,y
;         sta     aws_tmp02
;         ldx     #$00
; @copy_uri:
;         cpx     aws_tmp02
;         beq     @mount_live
;         iny
;         lda     _fuji_rx_buffer,y
;         sta     _fuji_current_fs_uri,x
;         inx
;         bne     @copy_uri

; @mount_live:
;         lda     #$00
;         sta     _fuji_current_fs_uri,x
;         lda     #<_fuji_current_fs_uri
;         sta     aws_tmp00
;         lda     #>_fuji_current_fs_uri
;         sta     aws_tmp01
;         lda     current_drv
;         clc
;         adc     #$01
;         ldx     #$00
;         jsr     fn_disk_mount
;         bcs     bad_mount_slot

;         ; Bridge mapping table used later by DFS disk I/O:
;         ;   BBC drive number -> FujiNet mount slot index
;         ldx     current_drv
;         lda     fuji_disk_table_index
;         sta     fuji_drive_disk_map,x

;         ; Standard success path: zero user flag.
;         ldx     #$00
;         jmp     set_user_flag_x

