; *FIN command implementation
; Find a file on a specific drive
; Syntax: *FIN <drive> <filename>

        .export cmd_fs_fin

        .import err_bad
        .import param_count_a
        .import param_drive_or_default
        .import param_get_string
        .import fn_disk_mount
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fin - Handle *FIN command
; Syntax: *FIN <drive> <filename>
; Finds and displays information about a file on a specific drive
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fin:
        ; Check parameter count (1 or 2 allowed)
        lda     #$80                    ; flag7=1, flag0=0: allows 1-2 parameters
        jsr     param_count_a           ; Returns C=0 if 1 param, C=1 if 2

        ; Read drive parameter or use default
        jsr     param_drive_or_default  ; Sets current_drv

        bcc     fin_mount_current_uri

        ; Two-parameter form: read filename and append or replace onto current URI.
        jsr     param_get_string
        bcc     fin_bad_filename

        ldy     #$00
@copy_filename:
        lda     fuji_filename_buffer,y
        sta     fuji_current_dir_path,y
        iny
        cpy     #$40
        bcc     @copy_filename

        dey
        sty     fuji_current_dir_len

fin_mount_current_uri:
        ldx     fuji_current_fs_len
        beq     fin_bad_uri

        ; Build mountable URI into fuji_filename_buffer.
        ldy     #$00
@copy_base:
        lda     fuji_current_fs_uri,y
        sta     fuji_filename_buffer,y
        beq     @base_done
        iny
        cpy     #$3F
        bcc     @copy_base

@base_done:
        ; If current path is just root, use the current FS URI as-is.
        lda     fuji_current_dir_len
        cmp     #$01
        bne     @append_current_path
        lda     fuji_current_dir_path
        cmp     #'/'
        beq     @mount_uri_ready

@append_current_path:
        dey
        lda     fuji_filename_buffer,y
        cmp     #'/'
        beq     @append_loop_prep
        iny
        lda     #'/'
        sta     fuji_filename_buffer,y

@append_loop_prep:
        iny
        ldx     #$00
@append_loop:
        lda     fuji_current_dir_path,x
        sta     fuji_filename_buffer,y
        beq     @mount_uri_ready
        inx
        iny
        cpx     #$3F
        bcc     @append_loop

@mount_uri_ready:
        sty     aws_tmp02
        lda     #<fuji_filename_buffer
        sta     aws_tmp00
        lda     #>fuji_filename_buffer
        sta     aws_tmp01

        lda     current_drv
        clc
        adc     #$01                    ; DiskService slots are 1-based
        ldx     #$00                    ; Mount read/write by default
        jsr     fn_disk_mount
        bcs     fin_mount_failed

        ldx     #$00
        jmp     set_user_flag_x

fin_bad_uri:
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0

fin_bad_filename:
        jsr     err_bad
        .byte   $CB
        .byte   "filename", 0

fin_mount_failed:
        ldx     #$01
        jmp     set_user_flag_x
