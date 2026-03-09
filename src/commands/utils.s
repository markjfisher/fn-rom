; Utility functions for commands

        .export _cmd_save_args_state

        .include "fujinet.inc"

        .segment "CODE"

_cmd_save_args_state:
    sty     fuji_cmd_offset_y
    rts
