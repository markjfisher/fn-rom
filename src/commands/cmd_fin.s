; *FIN command implementation
; Configure a persisted FujiNet mount slot with a URI
; Syntax: *FIN [<mount slot>] <filename>

        .export cmd_fs_fin

        .import err_bad
        .import fuji_set_mount_slot
        .import num_params
        .import param_get_num
        .import param_get_string
        .import set_user_flag_x

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fin - Handle *FIN command
;
; Supported forms:
;   *FIN <filename>
;       Store a URI into the current/default persisted FujiNet mount slot.
;
;   *FIN <mount slot> <filename>
;       Change the current/default persisted FujiNet mount slot, then store the
;       URI into that slot.
;
; Design split:
; - FIN does not perform a live BBC drive mount.
; - Instead it writes a URI into the FujiDevice persisted mount table using the
;   FujiDevice SetMount protocol through fuji_set_mount_slot.
; - FMOUNT is the separate command that bridges a persisted FujiNet slot onto a
;   BBC DFS drive.
;
; State used here:
; - fuji_current_mount_slot = current/default 0-based persisted mount slot
; - fuji_current_fs_uri     = current canonical URI base selected by FHOST/FFS
; - fuji_buf_1060          = temporary assembly buffer for the final URI
;
; Current simple strategy for URI assembly:
; 1. copy the canonical base URI into fuji_buf_1060
; 2. add a '/' only if the base URI did not already end with one
; 3. append the requested filename/resource leaf
;
; Placeholder / follow-up notes:
; - later review may want a shared helper for URI concatenation to reduce
;   repeated string-assembly logic across commands
; - bounds handling is intentionally minimal at present and worth emulator-side
;   scrutiny when long filenames/paths are exercised
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fin:
        ; Count parameters first so we can distinguish:
        ;   *FIN disk.ssd
        ;   *FIN 1 disk.ssd
        jsr     num_params
        cmp     #$01
        beq     @use_default_slot
        cmp     #$02
        beq     @read_explicit_slot
        jmp     fin_bad_filename

@read_explicit_slot:
        ; Read an explicit 0-based FujiNet mount slot index.
        ; If valid, this becomes the new current/default slot for later FIN.
        jsr     param_get_num
        cmp     #$08
        bcs     fin_bad_slot
        sta     fuji_current_mount_slot

@use_default_slot:
        ; Read the filename/resource leaf relative to the current URI base.
        ; param_get_string stores bytes in fuji_filename_buffer and returns the
        ; length in A.
        jsr     param_get_string
        bcc     fin_bad_filename

        ; There must already be a current URI base selected via FHOST/FFS.
        lda     fuji_current_fs_len
        beq     fin_bad_uri

        ; Build the final full URI in fuji_buf_1060.
        ldy     #$00
@copy_base:
        lda     fuji_current_fs_uri,y
        sta     fuji_buf_1060,y
        beq     @base_done
        iny
        cpy     #$3F
        bcc     @copy_base

@base_done:
        ; Y is one past the copied NUL terminator, so step back to inspect the
        ; final real character of the base URI.
        dey
        lda     fuji_buf_1060,y
        cmp     #'/'
        beq     @append_name

        ; Base URI did not end in '/', so insert one before the filename.
        iny
        lda     #'/'
        sta     fuji_buf_1060,y

@append_name:
        ; Append the requested filename/resource leaf including its NUL.
        iny
        ldx     #$00
@copy_name:
        lda     fuji_filename_buffer,x
        sta     fuji_buf_1060,y
        beq     @set_mount_done
        inx
        iny
        cpx     #$3F
        bcc     @copy_name

@set_mount_done:
        ; Persist the assembled URI into the current FujiNet mount slot.
        ; fuji_set_mount_slot reads:
        ;   fuji_current_mount_slot = target 0-based slot index
        ;   fuji_buf_1060           = final NUL-terminated URI
        jsr     fuji_set_mount_slot
        bcs     fin_mount_failed

        ; Standard success path: zero user flag.
        ldx     #$00
        jmp     set_user_flag_x

fin_bad_uri:
        ; No current URI base was selected before FIN was used.
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0

fin_bad_filename:
        ; Generic filename/resource argument error.
        jsr     err_bad
        .byte   $CB
        .byte   "filename", 0

fin_bad_slot:
        ; Persisted FujiNet mount slots are currently limited to 0..7.
        jsr     err_bad
        .byte   $CB
        .byte   "mount slot", 0

fin_mount_failed:
        ; Non-zero user flag indicates command failure.
        ldx     #$01
        jmp     set_user_flag_x
