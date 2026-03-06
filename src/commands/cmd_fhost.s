        .export cmd_fs_fhost
        .export fhost_show_current_fs
        .export fhost_set_current_fs

        .import err_bad
        .import err_syntax
        .import exit_user_ok
        .import fn_file_resolve_path
        .import fuji_set_mount_slot
        .import num_params
        .import param_get_string
        .import print_char
        .import print_newline
        .import print_space
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fhost - Handle *FHOST / *FFS command
;
; Supported forms:
;   *FHOST
;       Print the currently selected full URI and the current human-facing path.
;
;   *FHOST <uri>
;   *FFS   <uri>
;       Store a new current filesystem selection and ask FileDevice ResolvePath
;       to canonicalize it immediately.
;
; Design split:
; - FHOST/FFS are the URI-facing commands.
; - The BBC stores two related values:
;     fuji_current_fs_uri   -> canonical full URI for machine/protocol use
;     fuji_current_dir_path -> display path for human-facing output only
; - URI and path semantics are intentionally delegated to FujiNet-NIO via
;   FileDevice ResolvePath rather than reimplemented in 6502.
;
; ResolvePath usage here:
; - baseUriLen/baseUri are taken from the just-stored fuji_current_fs_* fields
; - argLen is set to 0 so NIO canonicalizes the URI “as-is”
; - on success the helper refreshes both URI and display-path state
;
; Placeholder / follow-up notes:
; - current fallback on ResolvePath failure is conservative: keep the typed URI
;   but reset the display path to "/"
; - richer error reporting could later distinguish invalid URI from transport
;   failure if fn_file_resolve_path exposes more detail
;
; FHOST vs FMOUNT: FMOUNT reads the FujiNet persisted mount table (GetMount(slot)).
; FHOST only sets the BBC "current" URI. So that *FMOUNT 0 0* works after *FHOST <uri>*,
; we persist the newly set URI to FujiNet slot 0 after ResolvePath success.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fhost:
        ; Count parameters first so we can choose the no-argument display form
        ; or the one-argument set-current-URI form without consuming input yet.
        jsr     num_params
        cmp     #$00
        beq     fhost_show_current_fs
        cmp     #$01
        beq     fhost_set_current_fs
        jmp     err_syntax

fhost_show_current_fs:
        ; Print the stored canonical full URI first.
        jsr     print_newline
        jsr     print_string
        .byte   "FS", 0
        jsr     print_space

        ldx     fuji_current_fs_len
        beq     @print_none

        ldy     #$00
@print_fs_loop:
        lda     fuji_current_fs_uri,y
        beq     @print_path
        jsr     print_char
        iny
        bne     @print_fs_loop

@print_path:
        ; Print the corresponding human-facing current path. This is kept
        ; separate from the URI specifically so commands like FCD can show a
        ; simple path such as "/root/NEXT".
        jsr     print_newline
        jsr     print_string
        .byte   "DIR", 0
        jsr     print_space

        ldx     fuji_current_dir_len
        beq     @print_root

        ldy     #$00
@print_dir_loop:
        lda     fuji_current_dir_path,y
        beq     @done
        jsr     print_char
        iny
        bne     @print_dir_loop

@done:
        jmp     print_newline

@print_none:
        ; No current URI has been selected yet.
        jsr     print_string
        .byte   "(none)", 0
        jmp     @print_path

@print_root:
        ; No display path stored -> treat as root for printing.
        lda     #'/'
        jsr     print_char
        jmp     @done

fhost_set_current_fs:
        ; Read the user-supplied full URI into fuji_filename_buffer.
        ; param_get_string returns the URI length in A on success.
        jsr     param_get_string
        bcc     err_bad_uri

        ; Persist the raw typed URI length and bytes first so we always retain
        ; the user's selection even if ResolvePath later fails.
        sta     fuji_current_fs_len

        ldy     #$00
@copy_uri_loop:
        lda     fuji_filename_buffer,y
        sta     fuji_current_fs_uri,y
        beq     @copy_done
        iny
        cpy     fuji_current_fs_len
        bcc     @copy_uri_loop

@copy_done:
        ; Prepare FileDevice ResolvePath inputs to canonicalize the URI as-is:
        ;
        ; aws_tmp00/01 -> pointer to current URI buffer
        ; aws_tmp02    -> current URI length
        ; aws_tmp03/04 -> placeholder arg pointer (unused because arg length=0)
        ; aws_tmp05    -> 0, meaning “canonicalize this full URI directly”
        lda     #<fuji_current_fs_uri
        sta     aws_tmp00
        lda     #>fuji_current_fs_uri
        sta     aws_tmp01
        lda     fuji_current_fs_len
        sta     aws_tmp02
        lda     #<fuji_buf_1072
        sta     aws_tmp03
        lda     #>fuji_buf_1072
        sta     aws_tmp04
        lda     #$00
        sta     aws_tmp05

        ; Delegate URI normalization and display-path derivation to the NIO
        ; side. On success this overwrites both current URI and current path
        ; with canonical values.
        jsr     fn_file_resolve_path
        bcc     @resolved_ok

        ; Conservative fallback if the helper/protocol fails: retain the typed
        ; URI but degrade the display path to root so later commands still see
        ; a minimally coherent path state.
        lda     #'/'
        sta     fuji_current_dir_path
        lda     #$00
        sta     fuji_current_dir_path+1
        lda     #$01
        sta     fuji_current_dir_len
        jmp     exit_user_ok

@resolved_ok:
        ; Persist this URI to FujiNet slot 0 so *FMOUNT 0 0* works without FIN.
        ; fuji_set_mount_slot expects NUL-terminated URI in fuji_buf_1060.
        ldy     #$00
@copy_to_buf:
        cpy     fuji_current_fs_len
        beq     @nul_term
        lda     fuji_current_fs_uri,y
        sta     fuji_buf_1060,y
        iny
        bne     @copy_to_buf
@nul_term:
        lda     #$00
        sta     fuji_buf_1060,y
        lda     #$00
        sta     fuji_current_mount_slot
        jsr     fuji_set_mount_slot
        ; Ignore carry: current FS is already set; FMOUNT may retry or use FIN.

        ; Successful completion exits through the standard ROM command helper.
        jmp     exit_user_ok

err_bad_uri:
        ; Standard ROM “Bad uri” error path.
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0
