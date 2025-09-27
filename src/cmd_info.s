; *INFO command implementation for FujiNet ROM
; Contains both FSCV and command table implementations

        .export fscv10_starINFO
        .export cmd_fs_info

        .import print_string
        .import print_axy
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV10_STARINFO - Handle *INFO command via FSCV
; This is called when *INFO is used on the active filing system
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv10_starINFO:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "FSCV10_STARINFO called", $0D
        nop
        jsr     print_axy
.endif
        
        ; Set up text pointer and command index (following MMFS pattern)
        ; TODO: Implement SetTextPointerYX equivalent
        ; For now, just set up the command index
        lda     #$01                    ; INFO command index in cmd_table_fujifs
        sta     aws_tmp00               ; Store command index for CMD_INFO
        
        ; Fall through to CMD_INFO implementation (no JMP needed!)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_INFO - Handle *INFO command
; This is the shared implementation called by both:
; - fscv10_starINFO (when *INFO is called on active filing system)
; - cmd_table_fujifs (when *FUJI INFO is called)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_info:
.ifdef FN_DEBUG
        jsr     remember_axy
        jsr     print_string
        .byte   "CMD_FS_INFO called", $0D
        nop
        jsr     print_axy
.endif
        
        ; TODO: Implement proper INFO command
        
        rts
