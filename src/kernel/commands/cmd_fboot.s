        .export cmd_fs_fboot

        .import current_cat
        .import exit_user_ok
        .import fuji_restore_boot_disk
        .import report_error

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fboot - Restore the configured boot/config disk to BBC drive 0
;
; Syntax:
;   *FBOOT
;
; This is a manual config-disk restore. It does not start a new host session;
; hard/power reset owns that boundary via BeginHostSession.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fboot:
        jsr     fuji_restore_boot_disk
        bcs     err_fboot

        lda     #$FF
        sta     current_cat             ; force next catalogue access to reload drive 0
        jmp     exit_user_ok

err_fboot:
        jsr     report_error
        .byte   $CB
        .byte   "FBOOT err", 0
