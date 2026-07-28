        .export cmd_fs_fboot

        .import current_cat
        .import err_syntax
        .import exit_user_ok
        .import fuji_restore_boot_disk
        .import num_params
        .import param_drive_no_syntax
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fboot - Restore the configured boot/config disk to a BBC drive
;
; Syntax:
;   *FBOOT
;   *FBOOT <drive>
;
; This is a manual config-disk restore. It does not start a new host session;
; hard/power reset owns that boundary via BeginHostSession.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fboot:
        jsr     num_params
        beq     @drive0
        cmp     #$01
        bne     err_fboot_syntax

        jsr     param_drive_no_syntax
        bcc     @restore

@drive0:
        lda     #$00

@restore:
        jsr     fuji_restore_boot_disk
        bcs     err_fboot

        lda     #$FF
        sta     current_cat             ; force next catalogue access to reload
        jmp     exit_user_ok

err_fboot_syntax:
        jmp     err_syntax

err_fboot:
        jsr     report_error
        .byte   $CB
        .byte   "FBOOT err", 0
