; *TITLE command implementation
; Translated from MMFS CMD_TITLE (lines 2308-2348)
; Syntax: *TITLE <title>

        .export cmd_fs_title
        .export set_disk_title_chr_xpos

        .import param_syntaxerrorifnull
        .import set_curdrv_to_default
        .import load_cur_drv_cat2
        .import save_cat_to_disk
        .import GSREAD_A

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_title - Handle *TITLE command
; Translated from MMFS CMD_TITLE (lines 2308-2348)
; Sets the disk title (12 characters max: 8 in sector 0, 4 in sector 1)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_title:
        jsr     param_syntaxerrorifnull
        
        ; Set directory and drive to defaults
        lda     fuji_default_dir
        sta     directory_param
        jsr     set_curdrv_to_default
        jsr     load_cur_drv_cat2       ; Load cat

        ; Blank title (fill with 0)
        ldx     #$0B                    ; 12 characters (0-11)
        lda     #$00

@cmdtit_loop1:
        jsr     set_disk_title_chr_xpos
        dex
        bpl     @cmdtit_loop1

@cmdtit_loop2:
        inx                             ; Read title from parameter
        jsr     GSREAD_A
        bcs     @cmdtit_savecat         ; End of string
        jsr     set_disk_title_chr_xpos
        cpx     #$0B
        bcc     @cmdtit_loop2

@cmdtit_savecat:
        jsr     save_cat_to_disk        ; Save cat
        ; Note: MMFS also calls UpdateDiskTableTitle here, but we don't have disk tables
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; set_disk_title_chr_xpos - Set disk title character at position X
; Translated from MMFS SetDiskTitleChr_Xpos (lines 2336-2346)
; Input: A = character to set
;        X = position (0-11)
;              0-7 go to $0E00+X (sector 0)
;              8-11 go to $0EF8+X (sector 1, offset -8 so 8->$0F00, 9->$0F01, etc)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_disk_title_chr_xpos:
        cpx     #$08
        bcc     @setdisttit_page
        sta     dfs_cat_s1_header-8,x   ; $0EF8+X = $0F00-8+X
        rts

@setdisttit_page:
        sta     dfs_cat_s0_header,x     ; $0E00+X
        rts

