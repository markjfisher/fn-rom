        .export cmd_fs_funmount

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
