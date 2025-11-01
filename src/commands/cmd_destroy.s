; *DESTROY command implementation
; Translated from MMFS CMD_DESTROY (lines 1898-1927)
; *DESTROY <afsp> - Delete all files matching wildcard (requires *ENABLE)

        .export cmd_fs_destroy

        .import check_for_disk_change
        .import delete_cat_entry_adjust_ptr
        .import get_cat_firstentry80
        .import get_cat_nextentry
        .import go_yn
        .import is_enabled_or_go
        .import parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .import print_newline
        .import print_string
        .import prt_filename_yoffset
        .import save_cat_to_disk

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_destroy - Handle *DESTROY command
; Deletes all files matching wildcard after confirmation
; Requires *ENABLE to be run first
; Syntax: *DESTROY <afsp>
; Translated from MMFS CMD_DESTROY (lines 1898-1927)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_destroy:
        jsr     is_enabled_or_go        ; Check if enabled or get confirmation
        jsr     parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp

        ; First pass: list all matching files
@destroyloop1:
        lda     dfs_cat_file_dir,y      ; Check if file is locked
        bmi     @destroylocked1         ; Skip if locked
        jsr     prt_filename_yoffset    ; Print filename
        jsr     print_newline
@destroylocked1:
        jsr     get_cat_nextentry       ; Get next matching entry
        bcs     @destroyloop1           ; Loop if more files

        ; Confirm with user
        jsr     go_yn                   ; Ask "Go (Y/N) ?"
        bne     cmd_exit                ; If not Y, exit
        jsr     check_for_disk_change

        ; Second pass: delete all matching unlocked files
        jsr     get_cat_firstentry80    ; Get first matching entry again
@destroyloop2:
        lda     dfs_cat_file_dir,y      ; Check if file is locked
        bmi     @destroylocked2         ; Skip if locked
        jsr     delete_cat_entry_adjust_ptr ; Delete and adjust pointer
@destroylocked2:
        jsr     get_cat_nextentry       ; Get next matching entry
        bcs     @destroyloop2           ; Loop if more files

        jsr     save_cat_to_disk        ; Save catalog
        ; Fall through to print "Deleted" message

msg_deleted:
        jsr     print_string
        .byte   "Deleted", $0D
        nop
cmd_exit:
        rts

