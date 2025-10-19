; *RENAME command implementation
; Translated from MMFS CMD_RENAME (lines 2794-2834)
; Syntax: *RENAME <old fsp> <new fsp>

        .export cmd_fs_rename

        .import parameter_fsp
        .import param_syntaxerrorifnull
        .import read_fsp_text_pointer
        .import get_cat_entry
        .import check_file_not_locked_or_open_y
        .import get_cat_firstentry80
        .import save_cat_to_disk
        .import y_add8
        .import err_bad_drive
        .import report_error_cb

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_rename - Handle *RENAME command
; Translated from MMFS CMD_RENAME (lines 2794-2834)
; Renames a file, checking that:
;   1. Source file exists and is not locked/open
;   2. Destination name doesn't already exist (or is same file)
;   3. Drive doesn't change
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_rename:
        jsr     parameter_fsp
        jsr     param_syntaxerrorifnull
        jsr     read_fsp_text_pointer   ; Read old filename
        tya
        pha                             ; Save Y
        jsr     get_cat_entry           ; Find old file
        jsr     check_file_not_locked_or_open_y
        sty     pws_tmp04               ; Save old file offset
        pla
        tay                             ; Restore Y
        jsr     param_syntaxerrorifnull ; Check for new name parameter
        lda     current_drv
        pha                             ; Save current drive
        jsr     read_fsp_text_pointer   ; Read new filename
        pla
        cmp     current_drv             ; Drive changed?
        bne     @jmp_bad_drive          ; Yes, error

        jsr     get_cat_firstentry80    ; Check if new name exists
        bcc     @rname_ok               ; Not found, OK
        cpy     pws_tmp04               ; Same file?
        beq     @rname_ok               ; Yes, OK (renaming to itself)

@err_file_exists:
        jsr     report_error_cb
        .byte   $C4
        .byte   "Exists", 0

@jmp_bad_drive:
        jmp     err_bad_drive

@rname_ok:
        ; Copy filename from $C5-$CC to catalog
        ldy     pws_tmp04               ; Get old file offset
        jsr     y_add8                  ; Y += 8 (skip to last byte)
        ldx     #$07                    ; Copy 8 bytes (7 down to 0)

@rname_loop:
        lda     pws_tmp05,x             ; Read from $C5+X
        sta     dfs_cat_s0_title+7,y    ; Store to $0E07+Y (going backwards)
        dey
        dex
        bpl     @rname_loop

        jmp     save_cat_to_disk        ; Save catalog

