; *OPT command implementation
; Based on MMFS fscv0_starOPT (line 2393)
; Supports:
;   *OPT 0,Y - Message control (Y=0: messages on, Y≠0: messages off)
;   *OPT 1,Y - Message control (same as OPT 0)
;   *OPT 4,Y - Boot option (Y=0: L.!BOOT, Y=1: E.!BOOT, Y=2: !BOOT)
;   *OPT 5,Y - Disk trap option (disable *DISC/*DISK commands)
;   *OPT 6,Y - Network flush mode (Y=0: buffered, Y≠0: immediate)
;   *OPT 7,Y - Network NotReady retry count (Y=0: default 24, Y=1-255: max attempts)

        .export fscv0_starOPT

        .importzp paged_ram_copy

        .import a_rolx4
        .import dfs_cat_boot_option
        .import err_bad
        .import fuji_fs_messages_on
        .import fuji_network_flush_mode
        .import fuji_network_retry_max
        .import load_cur_drv_cat
        .import paged_rom_priv_ws
        .import remember_axy
        .import save_cat_to_disk
        .import set_curdir_drv_to_defaults

        .include "fujinet.inc"

fscv0_starOPT:
        jsr     remember_axy
        txa
        cmp     #$04
        beq     set_boot_option_yoption
        cmp     #$05
        beq     disk_trap_option
        cmp     #$06
        beq     set_net_flush_option        ; OPT 6: network flush mode
        cmp     #$07
        beq     set_net_retry_max_option    ; OPT 7: network retry count
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
        eor     dfs_cat_boot_option        ; XOR with catalog header
        and     #$30                       ; Mask boot option bits
        eor     dfs_cat_boot_option        ; XOR back to preserve other bits
        sta     dfs_cat_boot_option        ; Store modified header
        jmp     save_cat_to_disk           ; save cat

disk_trap_option:
        ; *OPT 5,Y - Disk trap option (following MMFS lines 2428-2445)
        ; On non-Master builds, bit 6 of PagedROM_PrivWorkspaces disables
        ; *DISC/*DISK handling in this ROM. Master DFS always has higher priority,
        ; so MMFS omits the flag update there.

.ifndef FUJINET_MACHINE_MASTER
        tya                            ; A = Y (*OPT 5,Y value), sets Z if Y was 0
        php                            ; Save Y=0 flag
        ldx     paged_ram_copy         ; Get current ROM number
        lda     paged_rom_priv_ws,x    ; Get current flags
        and     #$BF                   ; Clear bit 6 (enable DISC/DISK as FujiNet commands)
        plp                            ; Restore Y=0 flag
        beq     skip_set_bit6          ; If Y=0, leave bit 6 clear
        ora     #$40                   ; Set bit 6 (disable DISC/DISK, pass to DFS)
skip_set_bit6:
        sta     paged_rom_priv_ws,x    ; Store updated flags
.endif

        rts

; *OPT 6,Y — Network flush mode
; Y=0: buffer mode (flush every 256 bytes, default)
; Y≠0: immediate mode (flush after every BPUT)
set_net_flush_option:
        tya
        beq     @flush_buffered
        lda     #$01
@flush_buffered:
        sta     fuji_network_flush_mode

        rts

; *OPT 7,Y — Network NotReady max retry attempts per TranslateConfigure / Read
; Y=0: default (NET_RETRY_MAX, currently 24)
; Y=1-255: max attempts before giving up on the current operation
set_net_retry_max_option:
        tya
        bne     @store
        lda     #NET_RETRY_MAX
@store:
        sta     fuji_network_retry_max

        rts
