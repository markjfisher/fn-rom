; *WIPE command implementation
; Translated from MMFS CMD_WIPE (lines 1862-1883)
; *WIPE <afsp> - Delete files with confirmation for each

        .export cmd_fs_wipe

        .importzp aws_tmp06

        .import check_for_disk_change
        .import confirm_yn_colon
        .import delete_cat_entry_adjust_ptr
        .import dfs_cat_file_dir
        .import get_cat_nextentry
        .import parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .import prt_filename_yoffset
        .import save_cat_to_disk

        .include "fujinet.inc"

        ; Self-register into the command group (Lever B). Present iff this
        ; module is built as a boot/config disk utility -- no resident command-table entry.
        cmd_entry "FUJIFS_EXT", "WIPE",    $2, $00, cmd_fs_wipe      ; <afsp>

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
        ; save Y across save_cat_to_disk — that path calls fuji_begin_transaction,
        ; which sets buffer_ptr (cws_tmp4/5) and must not use cws_tmp4 as scratch
        tya
        pha
        jsr     save_cat_to_disk        ; Save catalog
        pla
        sta     aws_tmp06               ; Update catalog pointer (was Y)
@wipenext:
        jsr     get_cat_nextentry       ; Get next matching entry
        bcs     @wipeloop               ; Loop if more files
        rts

