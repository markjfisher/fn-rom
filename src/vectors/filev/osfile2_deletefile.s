; OSFILE operation 2 - Delete file
; Handles file deletion operations
; Translated from MMFS mmfs100.asm lines 4301-4305 (osfile6_delfile)

        .export osfile2_deletefile

        .import read_fspba_find_cat_entry
        .import check_file_not_locked_or_open_y
        .import delete_cat_entry_yfileoffset
        .import save_cat_to_disk
        .import set_param_block_pointer_b0
        .import load_addr_hi2
        .import exec_addr_hi2

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile2_deletefile - Delete file (A=2)
; OSFILE A=2: Delete named file and return its catalog information
;
; Input: Filename in parameter block
; Output: 
;   A = 1 (file found and deleted)
;   Parameter block updated with deleted file's attributes
; Translated from MMFS lines 4301-4305
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile2_deletefile:
        ; for tracing purposes, it always skips the first instruction if we break on it
        nop
        jsr     read_fspba_find_cat_entry ; Find file in catalog, Y=offset, X=offset too
        
        ; Check file is not locked or open
        jsr     check_file_not_locked_or_open_y
        
        ; Read file attributes to parameter block before deleting
        ; This allows the caller to see what was deleted
        jsr     read_file_attribs_to_b0_yoffset
        
        ; Delete the catalog entry
        jsr     delete_cat_entry_yfileoffset
        
        ; Save updated catalog to disk
        jsr     save_cat_to_disk
        
        ; Return A=1 (file found and deleted)
        lda     #$01
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read_file_attribs_to_b0_yoffset - Read file attributes to param block
; Input: Y = catalog offset
; Output: Parameter block at aws_tmp00 filled with file attributes
; Translated from MMFS lines 4233-4268 (ReadFileAttribsToB0_Yoffset)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_file_attribs_to_b0_yoffset:
        ; Set parameter block pointer
        jsr     set_param_block_pointer_b0
        
        ; Copy load address (bytes 2-5 of param block)
        ldy     #$02
        ldx     dfs_cat_num_x8          ; Get catalog offset
        lda     dfs_cat_file_load_addr,x
        sta     (aws_tmp00),y
        iny
        lda     dfs_cat_file_load_addr+1,x
        sta     (aws_tmp00),y
        
        ; Set high bytes of load address
        jsr     load_addr_hi2           ; Sets fuji_buf_1074/1075
        iny
        lda     fuji_buf_1074
        sta     (aws_tmp00),y
        iny
        lda     fuji_buf_1075
        sta     (aws_tmp00),y
        
        ; Copy exec address (bytes 6-9 of param block)
        iny     ; Y=6
        ldx     dfs_cat_num_x8
        lda     dfs_cat_file_exec_addr,x
        sta     (aws_tmp00),y
        iny
        lda     dfs_cat_file_exec_addr+1,x
        sta     (aws_tmp00),y
        
        ; Set high bytes of exec address
        jsr     exec_addr_hi2           ; Sets fuji_buf_1076/1077
        iny
        lda     fuji_buf_1076
        sta     (aws_tmp00),y
        iny
        lda     fuji_buf_1077
        sta     (aws_tmp00),y
        
        ; Copy file length (bytes 10-13 of param block)
        ; Start address = 0
        iny     ; Y=10
        lda     #$00
        sta     (aws_tmp00),y
        iny
        sta     (aws_tmp00),y
        iny
        sta     (aws_tmp00),y
        iny
        sta     (aws_tmp00),y
        
        ; End address = file length (bytes 14-17 of param block)
        iny     ; Y=14
        ldx     dfs_cat_num_x8
        lda     dfs_cat_file_size,x
        sta     (aws_tmp00),y
        iny
        lda     dfs_cat_file_size+1,x
        sta     (aws_tmp00),y
        iny
        lda     #$00                    ; High bytes of length = 0
        sta     (aws_tmp00),y
        iny
        sta     (aws_tmp00),y
        
        rts
