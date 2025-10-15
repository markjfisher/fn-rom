; CMD_FS_DISC - Handle *DISC/*DISK commands
; Following MMFS CMD_DISC pattern (lines 2928-2941)
        .export cmd_fs_disc

        .import cmd_fs_fuji
        .import init_fuji

        .import print_axy
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CMD_FS_DISC - Handle *DISC/*DISK commands 
; Following MMFS pattern - check OPT 5 flag to determine behavior
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_disc:
        dbg_string_axy "CMD_FS_DISC: "

        ; Following MMFS CMD_DISC pattern (lines 2928-2941)
        ; Check bit 6 of PagedROM_PrivWorkspaces to see if DISC/DISK should pass to DFS

        ldx     paged_ram_copy          ; Get current ROM number
        lda     paged_rom_priv_ws,x     ; Get private workspace flags  
        and     #$40                    ; Test bit 6 (OPT 5 flag)
        bne     pass_to_dfs             ; If bit 6 set, act like *FUJI (activate FujiNet)
        jmp     cmd_fs_fuji             ; If bit 6 clear, act like *FUJI (activate FujiNet)

pass_to_dfs:
        ; Bit 6 set - pass command to DFS by returning without action
        ; DFS ROM will handle the *DISC/*DISK command after we return
        rts
