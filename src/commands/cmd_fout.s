        .export cmd_fs_fout

        .import fn_disk_unmount
        .import fuji_clear_mount_slot
        .import fuji_unmount_disk
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
; This removes the persisted FujiNet mount entry currently bridged to the BBC
; drive, clears the BBC-side bridge mapping, and requests a live DiskService
; unmount for the corresponding 1-based disk slot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fout:
        ; Parse BBC drive number and mirror it into current_drv for consistency
        ; with the rest of the ROM's drive-handling conventions.
        jsr     param_drive_no_syntax
        sta     current_drv

        ; Look up the currently bridged persisted FujiNet mount slot for this BBC
        ; drive. If no bridge exists, treat the request as a failure.
        ldx     current_drv
        lda     fuji_drive_disk_map,x
        cmp     #$FF
        beq     @failed
        sta     fuji_current_mount_slot

        ; Remove the persisted FujiDevice mount definition first.
        jsr     fuji_clear_mount_slot
        bcs     @failed

        ; Clear the BBC-side bridge state regardless of whether a live disk slot
        ; was currently mounted.
        jsr     fuji_unmount_disk

        ; DiskDevice uses 1-based slot numbers on the wire. BBC drive N is backed
        ; by live disk slot N+1 when bridged.
        lda     current_drv
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
