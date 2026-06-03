; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info
        .export cmd_info_loop

        .importzp aws_tmp14
        .importzp aws_tmp15

        .import cmd_table_info
        .import get_cat_nextentry
        .import parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .import prt_infoline_yoffset
        .import set_text_pointer_yx

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV10_STARINFO - Handle *INFO command via FSCV
; This is called when *INFO is used on the active filing system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv10_starINFO:
        jsr     set_text_pointer_yx
        lda     #<(cmd_table_info - 1)  ; aws_tmp14/15 need to point to the INFO command entry-1
        sta     aws_tmp14
        lda     #>(cmd_table_info - 1)
        sta     aws_tmp15

        ; Fall through to cmd_fs_info (old .CMD_INFO)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_INFO - Handle *INFO command
; This is the shared implementation called by both:
; - fscv10_starINFO (when *INFO is called on active filing system)
; - cmd_table_fujifs (when *FUJI INFO is called)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_info:
        ; Parse the AFSP first so get_cat_entry/check_cur_drv_cat loads the
        ; catalog for the resolved target drive rather than whatever drive was
        ; left in current_drv by earlier commands.
        jsr     parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp

cmd_info_loop:
        jsr     prt_infoline_yoffset
        jsr     get_cat_nextentry
        bcs     cmd_info_loop
        rts
