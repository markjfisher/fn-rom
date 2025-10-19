        .export cmd_fs_dir
        .export cmd_fs_lib

        .import read_dir_drv_parameters

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_dir:
        ldx     #$00
        beq     set_dir_lib

cmd_fs_lib:
        ldx     #$02

set_dir_lib:
        jsr     read_dir_drv_parameters
        sta     fuji_default_drive, x
        lda     directory_param
        sta     fuji_default_dir, x
        rts
