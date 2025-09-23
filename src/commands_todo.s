        .export cmd_fs_drive
        .export cmd_fs_fboot
        .export cmd_fs_fuji
        .export cmd_fs_info
        ; .export cmd_help_futils
        ; .export cmd_help_utils
        .export cmd_utils_roms
        .export not_cmd_futils
        .export not_cmd_utils

        .import print_string

        .segment "CODE"

cmd_fs_drive:
cmd_fs_fboot:
cmd_fs_fuji:
cmd_fs_info:
        rts

cmd_utils_roms:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: cmd_utils_roms", $0D
        nop
.endif
        rts

not_cmd_futils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: not_cmd_futils", $0D
        nop
.endif
        rts

not_cmd_utils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: not_cmd_utils", $0D
        nop
.endif
        rts