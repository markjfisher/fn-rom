        .export cmd_fs_fout

        .import fn_disk_unmount
        .import param_drive_no_syntax
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fout:
        jsr     param_drive_no_syntax
        sta     current_drv
        clc
        adc     #$01
        jsr     fn_disk_unmount
        bcs     @failed
        ldx     #$00
        jmp     set_user_flag_x

@failed:
        ldx     #$01
        jmp     set_user_flag_x
