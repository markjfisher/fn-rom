; Command implementations for FujiNet ROM
; These are the actual command functions called by the command tables

        .export cmd_fs_drive
        .export cmd_fs_fboot
        .export cmd_fs_fuji
        .export cmd_utils_roms
        .export not_cmd_fs
        .export not_cmd_fujifs
        .export not_cmd_futils
        .export not_cmd_utils

        .import print_string
        .import print_char
        .import print_hex
        .import print_newline
        .import print_axy
        .import remember_axy
        .import init_fuji

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_DRIVE - Handle *DRIVE command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_drive:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_FS_DRIVE called", $0D
        nop
        jsr     print_axy
.endif
        
        ; TODO: Implement DRIVE command
        
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_FBOOT - Handle *FBOOT command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fboot:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_FS_FBOOT called", $0D
        nop
        jsr     print_axy
.endif
        
        ; TODO: Implement FBOOT command

        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_FUJI - Handle *FUJI command (filing system selection)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_fuji:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_FS_FUJI called", $0D
        nop
        jsr     print_axy
.endif
        
        ; Initialize FujiNet filing system (following MMFS CMD_CARD pattern)
        lda     #$FF                    ; Set A=$FF to indicate not a boot file
        jmp     init_fuji               ; Call the initialization function

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_UTILS_ROMS - Handle *ROMS command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_utils_roms:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "CMD_UTILS_ROMS called", $0D
        nop
        jsr     print_axy
.endif
        
        ; TODO: Implement ROMS command

        
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; NOT_CMD functions - Handle unrecognized commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

not_cmd_fs:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "NOT_CMD_FS called", $0D
        nop
        jsr     print_axy
.endif
        rts

not_cmd_fujifs:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "NOT_CMD_FUJIFS called", $0D
        nop
        jsr     print_axy
.endif
        rts

not_cmd_futils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "NOT_CMD_FUTILS called", $0D
        nop
        jsr     print_axy
.endif
        rts


not_cmd_utils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "NOT_CMD_UTILS called", $0D
        nop
        jsr     print_axy
.endif
        rts
