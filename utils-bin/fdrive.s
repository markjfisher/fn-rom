; *FDRIVE transient-utility binary entry (FN-UTLS.ssd, role-split Lever B).
;
; Loaded into RAM at PAGE and entered by the FS *RUN with fn-rom paged in, so it
; calls the resident command handler (cmd_fs_fdrive) and the kernel/disk helpers
; it needs directly at their ROM addresses (resolved via the generated rom_abi).
;
; *FDRIVE takes no arguments. The *RUN handoff does not point the GSINIT string
; pointer (text_pointer = $F2) at the command tail, so we point it at an empty
; (CR) line; cmd_fs_fdrive's num_params then reads 0 and proceeds exactly as the
; resident command does. It exits via exit_user_ok (resolved to the ROM).

        .export _util_start

        .importzp text_pointer
        .import   cmd_fs_fdrive

        .segment "CODE"

_util_start:
        lda     #<empty_line
        sta     text_pointer
        lda     #>empty_line
        sta     text_pointer+1
        ldy     #$00
        jmp     cmd_fs_fdrive           ; runs, then exits via exit_user_ok

empty_line:
        .byte   $0D
