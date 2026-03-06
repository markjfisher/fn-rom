        .export cmd_fs_fout

        .import fn_disk_unmount
        .import param_drive_no_syntax
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fout - Handle *FOUT command
;
; Syntax:
;   *FOUT <drive>
;
; This performs a live DiskService unmount for the slot corresponding to the
; supplied BBC drive number. This is distinct from removing a persisted FujiNet
; mount definition from the FujiDevice configuration table.
;
; Review note:
; - at present this converts a BBC drive number directly into a 1-based
;   DiskDevice slot number on the wire
; - if the FMOUNT bridge model evolves further, revisit whether FOUT should
;   also clear a bridge mapping or only affect the live slot state
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fout:
        ; Parse BBC drive number and mirror it into current_drv for consistency
        ; with the rest of the ROM's drive-handling conventions.
        jsr     param_drive_no_syntax
        sta     current_drv

        ; DiskDevice uses 1-based slot numbers on the wire, so convert from the
        ; BBC's internal 0-based drive numbering before calling fn_disk_unmount.
        clc
        adc     #$01
        jsr     fn_disk_unmount
        bcs     @failed

        ; Standard success path: zero user flag.
        ldx     #$00
        jmp     set_user_flag_x

@failed:
        ; Non-zero user flag indicates command failure.
        ldx     #$01
        jmp     set_user_flag_x
