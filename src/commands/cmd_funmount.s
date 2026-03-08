        .export cmd_fs_funmount

        .import fuji_unmount_disk
        .import param_drive_no_syntax
        .import set_user_flag_x

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
        rts
;         ; Parse the BBC drive number, mirror it into current_drv, then clear only
;         ; the ROM-side bridge state for that drive.
;         jsr     param_drive_no_syntax
;         sta     current_drv
;         jsr     fuji_unmount_disk

;         ; Standard success path: zero user flag.
;         ldx     #$00
;         jmp     set_user_flag_x
