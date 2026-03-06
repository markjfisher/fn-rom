        .export cmd_fs_fmount

        .import err_bad
        .import param_count_a
        .import param_drive_or_default
        .import param_get_num
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fmount:
        lda     #$80                    ; allows 1-2 parameters
        jsr     param_count_a

        jsr     param_get_num           ; FujiNet mount slot index 0-7
        cmp     #$08
        bcs     bad_mount_slot
        sta     fuji_disk_table_index

        jsr     param_drive_or_default  ; optional BBC drive number
        sta     current_drv

        ; Bridge mapping: current BBC drive -> FujiNet mount slot index
        ldx     current_drv
        lda     fuji_disk_table_index
        sta     fuji_drive_disk_map,x

        ldx     #$00
        jmp     set_user_flag_x

bad_mount_slot:
        jsr     err_bad
        .byte   $CB
        .byte   "mount slot", 0
