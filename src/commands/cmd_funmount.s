        .export cmd_fs_funmount

        .import current_cat
        .import exit_user_ok
        .import fuji_drive_disk_map
        .import param_drive_no_syntax

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_funmount - Handle *FUNMOUNT command
;
; Syntax:
;   *FUNMOUNT <drive>
;
; This is the bridge-only inverse of FMOUNT. It clears the BBC drive ->
; FujiNet mount-slot mapping held in fuji_drive_disk_map without modifying the
; persisted FujiNet mount table maintained by FujiDevice.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_funmount:
        jsr     param_drive_no_syntax
        tax
        lda     #$FF
        sta     fuji_drive_disk_map,x    ; clear BBC drive -> slot bridge only
        sta     current_cat             ; invalidate cached catalog after unmapping a drive
        jmp     exit_user_ok
