; *ENABLE command implementation
; Translated from MMFS CMD_ENABLE (lines 2619-2622)
; *ENABLE allows the use of *BACKUP and *DESTROY commands

        .export cmd_fs_enable

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_enable - Handle *ENABLE command
; Sets the command enabled flag to allow dangerous commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_enable:
        lda     #$01
        sta     fuji_cmd_enabled
        rts

