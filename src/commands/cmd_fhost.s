        .export  _parse_fhost_params
        .export  _err_bad_uri
        .export  _err_set_uri

        .import  param_count
        .import  param_count_a
        .import  param_get_string

        .import  err_bad
        .import  report_error

        .import  print_char
        .import  print_string

        .import  fuji_filename_buffer
        .import  fuji_filename_len
        .import  fuji_error_flag
        .import  fuji_cmd_offset_y
        .import  set_fuji_fs_uri_ptr

        .include "fujinet.inc"

        .segment "CODE"

print_none:
        jsr     print_string
        .byte   "(none)"
        lda     #$00                    ; terminate string and be an instruction > $80
        rts

fhost_show_current:
        jsr     set_fuji_fs_uri_ptr     ; set buffer_ptr to fs_uri, we'll increment this to the dir part if needed later

        jsr     print_string
        ; .byte  $0D                    ; uncomment for a newline at the start
        .byte   "HOST: "                ; next byte must be above $80 to terminate the string, e.g. lda
        lda     fuji_current_fs_len
        bne     @show_host

        ; was not set, print none and skip to path
        jsr     print_none
        beq     @show_dir               ; always, return from print_none sets Z

@show_host:
        ; FS_URI = host://some-url/path/to/folder
        ; DIR_LEN is count of "/path/to/folder", so subtracting lengths gives the length of the host part
        ; print the length of the fs_uri minus the length of the dir in chars
        lda     fuji_current_fs_len
        sec
        sbc     fuji_current_dir_len

        sta     fuji_channel_scratch    ; save it in our tmp location so we can use it in dir path printing
        tax                             ; use as a counter

        jsr     print_from_buffer_x
        ; fall into show dir
@show_dir:
        lda     fuji_current_dir_len
        tax                             ; save for length
        bne     @do_show_dir
        jsr     print_none
        beq     @done

@do_show_dir:
        ; increment buffer_ptr by the host length, this can be done by adding the fs len, and subtracing the dir len
        ; but we already calculated this earlier, and if we have a path length, we must have a host, so safe
        ; to assume that the stored calculation is correct
        lda     buffer_ptr
        clc
        adc     fuji_channel_scratch
        sta     buffer_ptr
        bcc     :+
        inc     buffer_ptr + 1

:       ; x is just length of the dir to print, already set
        jsr     print_from_buffer_x

@done:
        rts

; print X chars from buffer_ptr
print_from_buffer_x:
        ldy     #$00
@print_loop_host:
        lda     (buffer_ptr), y
        jsr     print_char
        iny
        dex
        bne     @print_loop_host

; asm version of cmd_fs_fhost
cmd_fs_fhost:
        ; eventually we can fold this in and remove the jsr saving 3 bytes
        jsr     _parse_fhost_params
        beq     fhost_show_current

; do a resolve on this host string and set the fs_uri string, and dir len
        rts


; uint8_t parse_fhost_params()
;
; FHOST supports 0 or 1 parameters:
;   0 params: no action needed, return 0
;   1 param:  read string into fuji_filename_buffer, return 1
;
; Returns: A = param count (0 or 1)


_parse_fhost_params:
        ; Count parameters first. FHOST supports 0 or 1 parameters.
        ldy     fuji_cmd_offset_y       ; ensure the cmd line Y index is correct
        jsr     param_count             ; C=0 means 0 params, C=1 means 1 param

        ; Determine param count from carry flag
        bcs     @read_string

        lda     #$00            ; this may not be needed, with param_count, A should be 0 on exit
        tax                     ; this can be removed when we only use ASM *fhost
        rts

@read_string:
        ; We have 1 param - read the string
        clc                             ; string terminated by CR, space or quote
        jsr     param_get_string        ; reads into fuji_filename_buffer, returns length in A

        ; Store length
        sta     fuji_filename_len

        rts


_err_bad_uri:
        ; Standard ROM "Bad uri" error path.
        jsr     err_bad
        .byte   $CB
        .byte   "uri", 0

_err_set_uri:
        ; Standard ROM "Bad uri" error path.
        jsr     report_error
        .byte   $CB
        .byte   "Could not set host URI", 0
