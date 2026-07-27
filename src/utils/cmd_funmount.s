        .export cmd_fs_funmount

        .import current_cat
        .import exit_user_ok
        .import fuji_drive_disk_map
        .import param_drive_no_syntax

        .include "fujinet.inc"

        ; Self-register into the command group (Lever B). Present iff this
        ; module is built as a boot/config disk utility -- no resident command-table entry.
        ; *FUMOUNT (registered as "UMOUNT" + the F prefix). Kept to 7 chars so it
        ; also works as a transient FN-UTLS.ssd binary (DFS leaf limit is 7).
        cmd_entry "FUTILS_EXT", "UMOUNT", $3, $00, cmd_fs_funmount  ; <drive>

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_funmount - Handle *FUMOUNT command
;
; Syntax:
;   *FUMOUNT <drive>
;
; This is the bridge-only inverse of FMOUNT. It clears the BBC drive ->
; FujiNet mount-slot mapping held in fuji_drive_disk_map without modifying the
; persisted FujiNet mount table maintained by FujiDevice.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_funmount:
        jsr     param_drive_no_syntax
        tax
        lda     #$FF
        sta     fuji_drive_disk_map,x    ; clear BBC drive -> slot bridge only
        sta     current_cat             ; invalidate cached catalog after unmapping a drive
        jmp     exit_user_ok
