        .export cmd_fs_fout

        .import current_cat
        .import err_syntax
        .import exit_user_ok
        .import fuji_clear_slot
        .import fuji_disk_slot
        .import fuji_drive_disk_map
        .import fuji_get_slot
        .import fuji_unmount_disk
        .import param_count
        .import param_get_num
        .import report_error

        .include "fujinet.inc"

        ; Self-register into the command group (Lever B). Present iff this
        ; module is built as a boot/config disk utility -- no resident command-table entry.
        cmd_entry "FUTILS_EXT", "OUT",     $A, $00, cmd_fs_fout      ; <slot>

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fout - Handle *FOUT command
;
; Syntax:
;   *FOUT <slot>
;
; This removes the persisted FujiNet mount entry for the specified FujiNet slot.
; If that slot is currently bridged into a BBC drive, it also clears the BBC-side
; bridge mapping and requests a live DiskService unmount for that drive.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fout:
        jsr     param_count
        bcs     valid_count             ; 1 arg
        jmp     err_syntax

valid_count:
        jsr     param_get_num
        cmp     #$08
        bcs     err_fout
        sta     fuji_disk_slot

        jsr     fuji_get_slot
        cmp     #$00
        beq     err_fout

        jsr     fuji_clear_slot
        cmp     #$00
        beq     err_fout

        ldx     #$00
@scan_drives:
        lda     fuji_drive_disk_map,x
        cmp     fuji_disk_slot
        beq     @unmount_drive
        inx
        cpx     #$04
        bne     @scan_drives
        beq     @done

@unmount_drive:
        txa
        jsr     fuji_unmount_disk
        bcs     err_fout

@done:
        lda     #$FF
        sta     current_cat             ; invalidate cached catalog after removing mount
        jmp     exit_user_ok

err_fout:
        jsr     report_error
        .byte   $CB
        .byte   "FOUT err", 0
