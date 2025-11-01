; *ACCESS command implementation
; Translated from MMFS CMD_ACCESS (lines 2353-2389)
; Syntax: *ACCESS <fsp> (L)
; Lock or unlock files matching the filespec

        .export cmd_fs_access

        .import GSINIT_A
        .import GSREAD_A
        .import check_file_not_open_y
        .import err_bad
        .import get_cat_entry
        .import get_cat_nextentry
        .import param_syntax_error_if_null
        .import parameter_afsp
        .import prt_info_msg_yoffset
        .import read_fsp_text_pointer
        .import save_cat_to_disk

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fs_access - Handle *ACCESS command
; Syntax: *ACCESS <fsp> (L)
; Translated from MMFS CMD_ACCESS (lines 2353-2389)
; Sets or clears the locked flag for files matching filespec
; If "L" is specified, locks the files; otherwise unlocks them
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

cmd_fs_access:
        jsr     parameter_afsp          ; Set up wildcard parameters
        jsr     param_syntax_error_if_null ; Error if no filespec provided
        jsr     read_fsp_text_pointer   ; Read filespec from text pointer
        ldx     #$00                    ; X = locked mask (default: unlock)
        jsr     GSINIT_A                ; Check if string continues
        bne     cmdac_getparam          ; If not null, get parameter

cmdac_flag:
        stx     cws_tmp3                ; Store lock flag in &AA equivalent
        jsr     get_cat_entry           ; Get first matching catalog entry

cmdac_filefound:
        jsr     check_file_not_open_y
        
        ; Set/Reset locked flag
        lda     dfs_cat_file_dir,y      ; Get directory byte (MA+&0E0F,Y)
        and     #$7F                    ; Clear locked bit
        ora     cws_tmp3                ; Apply new lock flag
        sta     dfs_cat_file_dir,y      ; Store back
        
        jsr     prt_info_msg_yoffset    ; Print file info
        jsr     get_cat_nextentry       ; Get next matching entry
        bcs     cmdac_filefound         ; Loop if more files
        
        ; Save catalog with updated lock flags
        jmp     save_cat_to_disk

cmdac_paramloop:
        ldx     #$80                    ; Locked bit = $80

cmdac_getparam:
        jsr     GSREAD_A                ; Read next character
        bcs     cmdac_flag              ; If end of string, apply flag
        and     #$5F                    ; Convert to uppercase
        cmp     #'L'                    ; "L"?
        beq     cmdac_paramloop         ; Set lock bit and continue

err_bad_attribute:
        jsr     err_bad
        .byte   $CF
        .byte   "attribute", 0

