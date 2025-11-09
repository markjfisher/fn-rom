        .export cmd_fs_fhost
        .export fhost_list
        .export fhost_set_current_host
        .export fhost_set_host_url

        .import err_bad
        .import err_syntax
        .import num_params
        .import param_count_a
        .import param_get_num
        .import param_get_string

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_fhost - Handle *FHOST command
; Syntax: *FHOST <slot> <url>
; Muliple forms:
;  *FHOST                ; lists all host slots in fujinet
;  *FHOST n              ; sets the n'th host as the current host
;  *FHOST n url          ; sets the URL of the n'th host, and sets it active
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fhost:
        ; Check parameter count, 0-2 allowed
        jsr     num_params              ; returns param count in A

        cmp     #$01
        beq     fhost_set_current_host
        cmp     #$00
        beq     fhost_list
        cmp     #$02
        beq     fhost_set_host_url

        jmp     err_syntax

fhost_set_current_host:
        ; read the number, must be 1-8
        jsr     param_get_num
        cmp     #$00
        beq     err_bad_host_num
        cmp     #$09
        bcs     err_bad_host_num
        sta     current_host
        rts

err_bad_host_num:
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "host", 0

fhost_list:
        ; TODO
        rts

fhost_set_host_url:
        ; get the host number
        jsr     fhost_set_current_host
        ; read the host url parameter into fuji_filename_buffer
        ; C=0 if name was too long
        jsr     param_get_string
        bcc     err_bad_host_string

        ; we have current_host and fuji_filename_buffer set so tell FujiNet
        ; jsr     

        rts

err_bad_host_string:
        jsr     err_bad
        .byte   $CB                     ; again, not sure here
        .byte   "url", 0

