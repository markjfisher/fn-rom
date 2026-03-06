; *FIN command implementation
; Configure a persisted FujiNet mount slot with a URI
; Syntax: *FIN [<mount slot>] <filename>

        .export cmd_fs_fin

        .import err_bad
        .import fuji_set_mount_slot
        .import num_params
        .import param_get_num
        .import param_get_string
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fin - Handle *FIN command
; Syntax: *FIN [<mount slot>] <filename>
; Stores a URI into the persisted FujiNet mount table.
; If a mount slot is supplied, it becomes the new default slot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fin:
        jsr     num_params
        cmp     #$01
        beq     @use_default_slot
        cmp     #$02
        beq     @read_explicit_slot
        jmp     fin_bad_filename

@read_explicit_slot:
        jsr     param_get_num
        cmp     #$08
        bcs     fin_bad_slot
        sta     fuji_current_mount_slot

@use_default_slot:
        jsr     param_get_string
        bcc     fin_bad_filename

        lda     fuji_current_fs_len
        beq     fin_bad_uri

        ; Build final URI in fuji_buf_1060.
        ldy     #$00
@copy_base:
        lda     fuji_current_fs_uri,y
        sta     fuji_buf_1060,y
        beq     @base_done
        iny
        cpy     #$3F
        bcc     @copy_base

@base_done:
        dey
        lda     fuji_buf_1060,y
        cmp     #'/'
        beq     @append_name
        iny
        lda     #'/'
        sta     fuji_buf_1060,y

@append_name:
        iny
        ldx     #$00
@copy_name:
        lda     fuji_filename_buffer,x
        sta     fuji_buf_1060,y
        beq     @set_mount_done
        inx
        iny
        cpx     #$3F
        bcc     @copy_name

@set_mount_done:
        jsr     fuji_set_mount_slot
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

fin_bad_slot:
        jsr     err_bad
        .byte   $CB
        .byte   "mount slot", 0

fin_mount_failed:
        ldx     #$01
        jmp     set_user_flag_x
