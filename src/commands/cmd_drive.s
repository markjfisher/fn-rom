; *DRIVE command implementation
; Translated from MMFS mmfs100.asm lines 1951-1954

        .export cmd_fs_drive

        .import param_drive_no_syntax

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_DRIVE - Handle *DRIVE command
; Syntax: *DRIVE <n> where n = 0 or 1
; Translated from MMFS CMD_DRIVE (lines 1951-1954):
;   JSR Param_DriveNo_Syntax
;   STA DEFAULT_DRIVE
;   RTS
; Note: MMFS does NOT load the catalog here. It's loaded lazily later
; via CheckCurDrvCat when the catalog is actually needed.
;
; For the dummy interface, fuji_dummy.s reads current_drv ($CD) directly
; when needed, so no special handling required here.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_drive:
        jsr     param_drive_no_syntax   ; Parse drive number (from fs_functions.s)
        sta     fuji_default_drive      ; Store as default drive (matches MMFS)
        rts                             ; Done (catalog loaded lazily later)

