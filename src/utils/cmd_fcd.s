        .export  cmd_fs_fcd
        .export  fcd_commit_resolved_path
        .export  fcd_print_current_path
        .export  fcd_print_cws_tmp2_x

        .import exit_user_ok
        .import fhost_copy_and_resolve
        .import fhost_show_current
        .import fuji_filename_len
        .import param_count
        .import param_get_string
        .import print_newline

        .include "fujinet.inc"

        cmd_entry "FUTILS_EXT", "CD",      $7, $00, cmd_fs_fcd       ; (<path>)

        .segment "CODE"

cmd_fs_fcd:
        jsr     param_count
        bcc     fcd_show_current

        clc
        jsr     param_get_string
        sta     fuji_filename_len
        jsr     fhost_copy_and_resolve
        jmp     exit_user_ok

fcd_show_current:
        jsr     fhost_show_current
        jmp     exit_user_ok

; Compatibility exports retained for older unit labels.
fcd_commit_resolved_path:
        rts

fcd_print_current_path:
        jmp     print_newline

fcd_print_cws_tmp2_x:
        rts
