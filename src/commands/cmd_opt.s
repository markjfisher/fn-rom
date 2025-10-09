; *OPT command implementation
; Based on MMFS fscv0_starOPT (line 2393)
; Supports:
;   *OPT 0,Y - Message control (Y=0: messages on, Y≠0: messages off)
;   *OPT 1,Y - Message control (same as OPT 0)
;   *OPT 4,Y - Boot option (Y=0: L.!BOOT, Y=1: E.!BOOT, Y=2: !BOOT)
;   *OPT 5,Y - Disk trap option (disable *DISC/*DISK commands)

        .export fscv0_starOPT

        .import a_rolx4
        .import err_bad
        .import load_cur_drv_cat
        .import print_axy
        .import print_hex
        .import print_newline
        .import print_string
        .import remember_axy
        .import save_cat_to_disk
        .import set_curdir_drv_to_defaults

        .include "fujinet.inc"

fscv0_starOPT:
        dbg_string_axy "OPT: "

        jsr     remember_axy
        txa
        cmp     #$04
        beq     set_boot_option_yoption
        cmp     #$05
        beq     disk_trap_option
        cmp     #$02
        bcc     opts0_1                    ; If A<2

err_bad_option:
        jsr     err_bad
        .byte   $CB
        .byte   "option", 0

opts0_1:
        ; *OPT 0,Y or *OPT 1,Y - Message control

        ldx     #$FF                       ; Default: messages off
        tya
        beq     opts0_1_y0
        ldx     #$00                       ; Y≠0: messages on
opts0_1_y0:
        stx     fuji_fs_messages_on        ; =NOT(Y=0), i.e. FF=messages off

        rts

set_boot_option_yoption:
        ; *OPT 4,Y - Boot option
        tya
        pha
        jsr     set_curdir_drv_to_defaults
        jsr     load_cur_drv_cat           ; load cat
        pla
        jsr     a_rolx4                    ; A = A * 16
        eor     $0F06                      ; XOR with catalog header
        and     #$30                       ; Mask boot option bits
        eor     $0F06                      ; XOR back to preserve other bits
        sta     $0F06                      ; Store modified header

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "OPT: Boot opt, hdr: "
        nop
        lda     $0F06
        jsr     print_hex
        jsr     print_newline
.endif

        jmp     save_cat_to_disk           ; save cat

disk_trap_option:
        ; *OPT 5,Y - Disk trap option
        ; This controls whether *DISC and *DISK commands are disabled
        ; For FujiNet, we'll implement a simplified version

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "OPT: Disk trap", $0D
        nop
.endif

        tya
        pha
        ; TODO: Implement disk trap logic for FujiNet
        ; This would involve setting flags to disable certain commands
        pla
        rts

