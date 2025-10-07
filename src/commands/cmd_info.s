; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info

        .import cmd_table_info
        .import fuji_read_catalog
        .import get_cat_nextentry
        .import parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp
        .import print_axy
        .import print_string
        .import prt_infoline_yoffset
        .import set_text_pointer_yx

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV10_STARINFO - Handle *INFO command via FSCV
; This is called when *INFO is used on the active filing system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv10_starINFO:
        dbg_string_axy "FSCV10_STARINFO: "

        jsr     set_text_pointer_yx
        lda     #<(cmd_table_info - cmd_table_fujifs - 1) ; aws_tmp15 (BF) needs to point to the INFO command
        sta     aws_tmp15               ; equivalent of .Param_SyntaxErrorIfNull

        ; Fall through to cmd_fs_info (old .CMD_INFO)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_INFO - Handle *INFO command
; This is the shared implementation called by both:
; - fscv10_starINFO (when *INFO is called on active filing system)
; - cmd_table_fujifs (when *FUJI INFO is called)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_info:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_FS_INFO: "
        nop
        jsr     print_axy
.endif  
        ; Load catalog first
        jsr     fuji_read_catalog
        jsr     parameter_afsp_param_syntaxerrorifnull_getcatentry_fsptxtp

@cmd_info_loop:
        jsr     prt_infoline_yoffset
        jsr     get_cat_nextentry
        bcs     @cmd_info_loop
        rts

