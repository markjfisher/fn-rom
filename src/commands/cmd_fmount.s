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
        .import  num_params
        .import  param_get_num
        .import  param_get_string
        .import  param_optional_drive_no
        .import  print_newline
        .import  print_string_ax
        .import  report_error

        .include "fujinet.inc"

        .segment "CODE"


; Allow slot number to be 0-7
MAX_MOUNT_SLOT_COUNT := 8

; Allow drives 0-3
MAX_BBC_DRIVE  := 3

FMOUNT_FLAG_FORCE_RO := DISK_MOUNT_FLAG_READONLY


;------------------------------------------------------------------------------
; Main entry — same layout as cmd_fin.s (parse, FujiBus, exit_user_ok)
;------------------------------------------------------------------------------
cmd_fs_fmount:
        ; FMOUNT accepts:
        ;   *FMOUNT <slot>
        ;   *FMOUNT <slot> <drive>
        ;   *FMOUNT <slot> <drive> RO
        ; With no explicit mode, FMOUNT defaults to AUTO.

        jsr     num_params
        cmp     #$01
        bcc     @syntax_jump
        cmp     #$04
        bcs     @syntax_jump
        sta     cws_tmp7                ; number of params

        lda     #$00
        sta     fuji_channel_scratch    ; live mount flags, default AUTO

        jsr     param_get_num           ; FujiNet mount slot index 0-7, this errors if the value is not between 0-9

        cmp     #MAX_MOUNT_SLOT_COUNT
        bcc     @in_range
        jmp     err_bad_mount_slot

@in_range:
        sta     fuji_disk_slot

        ; Optional drive present?
        lda     cws_tmp7
        cmp     #$02
        bcc     @check_mode

        jsr     param_optional_drive_no

@check_mode:
        lda     cws_tmp7
        cmp     #$03
        bne     @done

        clc
        jsr     param_get_string
        tax                             ; length
        cpx     #$02
        bne     @bad_mode_jump

        lda     fuji_filename_buffer
        and     #$DF                    ; uppercase
        cmp     #'R'
        bne     @bad_mode_jump
        lda     fuji_filename_buffer+1
        and     #$DF
        cmp     #'O'
        bne     @bad_mode_jump

        lda     #FMOUNT_FLAG_FORCE_RO
        sta     fuji_channel_scratch
        bne     @done                   ; always

@syntax_jump:
        jmp     err_fmount_syntax

@bad_mode_jump:
        jmp     err_fmount_bad_mode

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
        ; [7]=slot, [8]=flags(bit0=enabled), [9]=uri_len, [10..]=uri,
        ; [10+uri_len]=mode_len, [11+uri_len..]=mode (slot default policy).
        ; BBC-side FMOUNT currently ignores persisted slot policy and uses a
        ; live mount policy: AUTO by default, or RO if explicitly requested.
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

        lda     fuji_channel_scratch
        jsr     fuji_mount_disk                         ; this uses "remember_xy_only" - can't rely on PLA to keep A set
        cmp     #$00
        beq     err_bad_disk_mount

        ; Disk mount response payload: [7]=version [8]=flags
        ; bit1 on flags means effective read-only.
        ldy     #$08
        lda     (buffer_ptr),y
        and     #DISK_MOUNT_RESP_FLAG_READONLY
        beq     @mount_success

        lda     #<str_fmount_readonly
        ldx     #>str_fmount_readonly
        jsr     print_string_ax
        jsr     print_newline

@mount_success:
        jmp     exit_user_ok

err_bad_disk_mount:
        jsr     report_error
        .byte   $CB
        .byte   "Failed to mount disk", 0

err_fmount_bad_mode:
        jsr     report_error
        .byte   $CB
        .byte   "Mode must be RO", 0

err_fmount_syntax:
        jsr     report_error
        .byte   $CB
        .byte   "Syntax: FMOUNT slot [drive] [RO]", 0

str_fmount_readonly:
        .byte   "Mounted read-only", 0
