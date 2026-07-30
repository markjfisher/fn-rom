; *FORM - recreate the writable SSD mounted in a BBC drive
;
; The command remains BBC-facing policy: it parses 40/80-track geometry,
; selects a BBC drive, and obtains destructive confirmation. FujiNet-NIO owns
; the mounted image URI and recreates that same image through DiskDevice.

        .export cmd_fs_form

        .importzp current_drv

        .import current_cat
        .import exit_user_ok
        .import fuji_channel_scratch
        .import fuji_reinitialize_disk
        .import fuji_set_disk_slot_from_mapping_or_error
        .import is_enabled_or_go
        .import num_params
        .import param_get_byte
        .import param_optional_drive_no
        .import print_newline
        .import print_nibble
        .import print_string

        .include "fujinet.inc"

        ; This registration is local to the transient FN-BOOT utility binary;
        ; the product ROM has no resident FORM command-table entry.
        cmd_entry "FUJIFS_EXT", "FORM", $5, $12, cmd_fs_form

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_form - Handle *FORM command
; Recreates the image currently mounted in a BBC drive.
; Syntax: *FORM <40|80> (<drive>)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_form:
        jsr     num_params
        cmp     #$01
        bcs     :+
        jmp     @syntax
:
        cmp     #$03
        bcc     :+
        jmp     @syntax
:

        jsr     param_get_byte
        cmp     #40
        beq     @tracks_ok
        cmp     #80
        beq     @tracks_ok
        jmp     @syntax

@tracks_ok:
        sta     fuji_channel_scratch
        jsr     param_optional_drive_no

        jsr     fuji_set_disk_slot_from_mapping_or_error
        bpl     :+
        jmp     @not_mounted
:

        jsr     print_string
        .byte   "Format drive "
        lda     current_drv
        jsr     print_nibble
        jsr     print_string
        .byte   " as "
        lda     fuji_channel_scratch
        cmp     #40
        bne     @print_80
        jsr     print_string
        .byte   "40 tracks", $0D
        nop
        jmp     @confirm

@print_80:
        jsr     print_string
        .byte   "80 tracks", $0D
        nop

@confirm:
        jsr     is_enabled_or_go

        lda     fuji_channel_scratch
        jsr     fuji_reinitialize_disk
        bcs     @format_error

        lda     #$FF
        sta     current_cat
        jsr     print_string
        .byte   "Formatted", $0D
        nop
        jmp     exit_user_ok

@syntax:
        jsr     print_string
        .byte   "Syntax: *FORM 40|80 (<drive>)", $0D
        nop
        jmp     exit_user_ok

@not_mounted:
        jsr     print_string
        .byte   "Not mounted", $0D
        nop
        jmp     exit_user_ok

@format_error:
        jsr     print_string
        .byte   "FORM err", $0D
        nop
        jmp     exit_user_ok
