; *WIPE command implementation
; Translated from MMFS CMD_WIPE (lines 1862-1883)
; *WIPE <afsp> - Delete files with confirmation for each

        .export cmd_fs_wipe

        .import parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .import prt_filename_yoffset
        .import confirm_yn_colon
        .import get_cat_nextentry
        .import check_for_disk_change
        .import delete_cat_entry_adjust_ptr
        .import save_cat_to_disk

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_wipe - Handle *WIPE command
; Deletes files matching wildcard with confirmation for each file
; Syntax: *WIPE <afsp>
; Translated from MMFS CMD_WIPE (lines 1862-1883)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_wipe:
        jsr     parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp

@wipeloop:
        lda     dfs_cat_file_dir,y      ; Check if file is locked
        bmi     @wipenext               ; Ignore locked files
        jsr     prt_filename_yoffset    ; Print filename
        jsr     confirm_yn_colon        ; Confirm Y/N with ": " prompt
        bne     @wipenext               ; If not Y, skip to next
        ldx     aws_tmp06               ; Save catalog pointer
        jsr     check_for_disk_change
        stx     aws_tmp06               ; Restore catalog pointer
        jsr     delete_cat_entry_adjust_ptr ; Delete and adjust pointer
        sty     cws_tmp4                ; Save Y
        jsr     save_cat_to_disk        ; Save catalog
        lda     cws_tmp4                ; Restore Y
        sta     aws_tmp06               ; Update catalog pointer
@wipenext:
        jsr     get_cat_nextentry       ; Get next matching entry
        bcs     @wipeloop               ; Loop if more files
        rts

