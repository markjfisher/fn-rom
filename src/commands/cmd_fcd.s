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
;         ; Count parameters first so we can distinguish the no-argument
;         ; "print current path" form from the one-argument traversal form.
;         jsr     num_params
;         cmp     #$00
;         beq     @print_current_path
;         cmp     #$01
;         bne     @bad

;         ; Read the requested path fragment into fuji_filename_buffer.
;         ; On success A returns the fragment length.
;         jsr     param_get_string
;         bcc     @bad_path
;         beq     @print_current_path
;         sta     aws_tmp05

;         lda     fuji_current_fs_len
;         beq     @bad_path

;         ; Prepare ResolvePath request inputs in the shared scratch locations.
;         ;
;         ; aws_tmp00/01 -> pointer to current canonical URI base
;         ; aws_tmp02    -> current URI length
;         ; aws_tmp03/04 -> pointer to requested path fragment buffer
;         ; aws_tmp05    -> requested path fragment length
;         lda     #<fuji_current_fs_uri
;         sta     aws_tmp00
;         lda     #>fuji_current_fs_uri
;         sta     aws_tmp01
;         lda     fuji_current_fs_len
;         sta     aws_tmp02
;         lda     #<fuji_filename_buffer
;         sta     aws_tmp03
;         lda     #>fuji_filename_buffer
;         sta     aws_tmp04

;         ; Delegate directory validation + canonicalization to FujiNet-NIO.
;         ; On success the helper refreshes both current URI and display path.
;         ; Path must exist on target (FujiNet stat); for FCD it must be a directory.
;         jsr     fn_file_resolve_path
;         bcs     @bad_path
;         lda     fuji_resolve_path_flags
;         and     #$01
;         beq     @bad_path

;         jmp     @print_current_path

; @print_current_path:
;         ; Print only the normalized human-facing path.
;         ; FHOST/FFS are the commands that display the full URI state.
;         lda     fuji_current_dir_len
;         bne     @path_ready
;         lda     #'/'
;         jsr     print_char
;         jmp     @done

; @path_ready:
;         ldy     #$00
; @loop:
;         lda     fuji_current_dir_path,y
;         beq     @done
;         jsr     print_char
;         iny
;         bne     @loop
; @done:
;         jsr     print_newline
;         ldx     #$00
;         jmp     set_user_flag_x

; @bad_path:
;         ; Current generic failure path for unresolved, invalid, missing, or
;         ; non-directory targets returned by ResolvePath handling.
;         jsr     err_bad
;         .byte   $CB
;         .byte   "directory", 0

; @bad:
;         ; Any form other than 0 or 1 parameters is syntax-invalid for FCD.
;         jsr     err_bad
;         .byte   $CB
;         .byte   "path", 0
