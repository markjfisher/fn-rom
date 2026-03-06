        .export cmd_fs_fout

        .import fn_disk_unmount
        .import fuji_clear_mount_slot
        .import fuji_get_mount_slot
        .import fuji_unmount_disk
        .import fn_rx_buffer
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

        ; DiskDevice uses 1-based slot numbers on the wire. BBC drive N is backed
        ; by live disk slot N+1 when bridged.
        txa
        clc
        adc     #$01
        sta     aws_tmp00

        ; Confirm the persisted slot still exists before we remove it. This keeps
        ; *FOUT as a persisted-mount operation rather than silently behaving like
        ; bridge-only *FUNMOUNT when the slot record is already absent.
        jsr     fuji_get_mount_slot
        bcs     @failed
        ldy     #FN_HEADER_SIZE+1
        lda     fn_rx_buffer,y
        and     #$01
        beq     @failed
        iny
        lda     fn_rx_buffer,y
        beq     @failed

        ; Request the live DiskService unmount only after the slot record was
        ; confirmed present.
        lda     aws_tmp00
        jsr     fn_disk_unmount
        bcs     @failed

        ; Remove the persisted FujiDevice mount definition only after the live
        ; unmount succeeded.
        jsr     fuji_clear_mount_slot
        bcs     @failed

        ; Both remote operations succeeded, so clear the local bridge last.
        jsr     fuji_unmount_disk

        ; Standard success path: zero user flag.
        ldx     #$00
        jmp     set_user_flag_x

@failed:
        ; Non-zero user flag indicates command failure.
        ldx     #$01
        jmp     set_user_flag_x
