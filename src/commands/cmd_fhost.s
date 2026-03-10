        .export cmd_fs_fhost
        .export _err_bad_uri

        .import err_bad

        .include "fujinet.inc"

        .segment "CODE"

_err_bad_uri:
err_bad_uri:
        ; Standard ROM “Bad uri” error path.
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0
