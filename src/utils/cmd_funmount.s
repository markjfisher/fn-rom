        .export cmd_fs_funmount

        .importzp current_drv

        .import GSINIT_A
        .import GSREAD_A
        .import current_cat
        .import exit_user_ok
        .import fuji_drive_disk_map
        .import fuji_unmount_disk
        .import num_params
        .import print_string

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
        ; Resident parameter helpers report malformed input through a BRK error.
        ; A transient *RUN utility must instead return normally to MOS, otherwise
        ; the handled error is followed by a misleading "Bad program".
        jsr     num_params
        cmp     #$01
        bne     @bad_drive

        jsr     GSINIT_A
        beq     @bad_drive
        jsr     GSREAD_A
        bcs     @bad_drive
        cmp     #'0'
        bcc     @bad_drive
        cmp     #'4'
        bcs     @bad_drive
        sec
        sbc     #'0'
        pha

        ; Only a single digit is a valid BBC drive parameter.
        jsr     GSREAD_A
        bcc     @bad_drive_pop
        pla
        sta     current_drv
        tax

        lda     fuji_drive_disk_map,x
        cmp     #$FF
        beq     @not_mounted

        jsr     fuji_unmount_disk
        bcs     @error
        lda     #$FF
        sta     current_cat             ; invalidate cached catalog after unmapping a drive
        jmp     exit_user_ok

@bad_drive_pop:
        pla
@bad_drive:
        jsr     print_string
        .byte   "Bad drive", $0D
        nop
        jmp     exit_user_ok

@not_mounted:
        jsr     print_string
        .byte   "Not mounted", $0D
        nop
        jmp     exit_user_ok

@error:
        jsr     print_string
        .byte   "FUMOUNT err", $0D
        nop
        jmp     exit_user_ok
