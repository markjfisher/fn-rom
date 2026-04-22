; Utility functions for commands

        ; cc65 command handlers lose Y before param parsing; MOS passes the CLI index in Y on entry.
        .export _cmd_save_args_state

        .include "fujinet.inc"

        .segment "CODE"

_cmd_save_args_state:
        rts
