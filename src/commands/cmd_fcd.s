        .export cmd_fs_fcd

        .import err_bad
        .import fn_file_resolve_path
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fcd - Handle *FCD command
;
; Supported forms:
;   *FCD
;       Print the current human-friendly path only.
;
;   *FCD <path>
;       Resolve <path> relative to the current canonical URI and, if accepted
;       by FujiNet-NIO as a valid directory target, update the ROM's stored
;       current URI and display path state.
;
; FileDevice ResolvePath usage:
; - baseUriLen/baseUri are taken from fuji_current_fs_len/fuji_current_fs_uri
; - argLen/arg are taken from the user string in fuji_filename_buffer
; - fn_file_resolve_path is responsible for protocol encoding/transport and,
;   on success, overwriting both:
;     fuji_current_fs_uri   ; canonical machine-facing URI
;     fuji_current_dir_path ; human-facing path such as "/root/NEXT"
;
; Intentional design choice:
; - the BBC ROM does not parse filesystem schemes, URI authorities, or relative
;   path semantics locally
; - those concerns stay on the FujiNet-NIO side in the shared resolver stack
;
; Placeholder / follow-up notes:
; - we should later decode ResolvePath response flags explicitly so FCD can
;   distinguish "exists but is not a directory" from generic resolution failure
; - current error handling intentionally collapses those cases into "Bad directory"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
cmd_fs_fcd:
        rts
