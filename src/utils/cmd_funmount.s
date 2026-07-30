        .export cmd_fs_funmount

        .import current_cat
        .import exit_user_ok
        .import fuji_unmount_disk
        .import param_drive_no_syntax
        .import report_error

        .include "fujinet.inc"

        ; Registration is local to the transient boot-disk utility binary;
        ; there is no resident command-table entry.
        ; *FUMOUNT (registered as "UMOUNT" + the F prefix). Kept to 7 chars so it
        ; also works as a transient FN-BOOT.ssd binary (DFS leaf limit is 7).
        cmd_entry "FUTILS_EXT", "UMOUNT", $3, $00, cmd_fs_funmount  ; <drive>

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_funmount - Handle *FUMOUNT command
;
; Syntax:
;   *FUMOUNT <drive>
;
; This is the runtime inverse of FMOUNT. It asks DiskService to unmount the
; selected BBC drive and clears the BBC drive map, without deleting the sparse
; catalog entry. Use FOUT when the catalog URI itself should be removed.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_funmount:
        jsr     param_drive_no_syntax
        jsr     fuji_unmount_disk
        bcs     @error
        lda     #$FF
        sta     current_cat             ; invalidate cached catalog after unmapping a drive
        jmp     exit_user_ok

@error:
        jsr     report_error
        .byte   $CB
        .byte   "FUMOUNT err", 0
