        .export cmd_fs_fdrive

        .import fuji_get_mounted_disk
        .import print_char
        .import print_decimal
        .import print_newline
        .import print_space
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fdrive:
        rts
