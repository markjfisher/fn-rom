; OSFILE operation 1 - Update catalog entry (write load/exec addresses)
; Handles updating file load and exec addresses in catalog
; Translated from MMFS mmfs100.asm lines 4306-4362

        .export osfile1_updatecat
        .export osfile_update_loadaddr_xoffset
        .export osfile_update_execaddr_xoffset
        .export osfile_savecat_reta_1

        .import read_fspba_find_cat_entry
        .import save_cat_to_disk
        .import remember_axy
        .import set_param_block_pointer_b0

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile1_updatecat - Update catalog entry (OSFILE A=1)
; Updates load and exec addresses for an existing file
; Translated from MMFS lines 4306-4310
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile1_updatecat:
        ; Find file in catalog (throws error if not found)
        jsr     read_fspba_find_cat_entry       ; Y=offset, X=offset
        
        ; Update load address
        jsr     osfile_update_loadaddr_xoffset
        
        ; Update exec address
        jsr     osfile_update_execaddr_xoffset
        
        ; Save catalog and return A=1
        jmp     osfile_savecat_reta_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_update_loadaddr_xoffset - Update load address in catalog
; Input: X = catalog offset, aws_tmp00/01 = parameter block pointer
; Translated from MMFS lines 4328-4342
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_update_loadaddr_xoffset:
        jsr     remember_axy
        jsr     set_param_block_pointer_b0
        
        ; Copy load address bytes 0-1 from parameter block to catalog
        ldy     #$02                            ; Param block offset for load addr
        lda     (aws_tmp00),y
        sta     dfs_cat_file_load_addr,x        ; MA+&0F08,X
        iny
        lda     (aws_tmp00),y
        sta     dfs_cat_file_load_addr+1,x      ; MA+&0F09,X
        
        ; Update high bits in mixed byte
        iny                                     ; Y=4, high byte of load addr
        lda     (aws_tmp00),y
        asl     a                               ; Shift left twice to position bits
        asl     a
        eor     dfs_cat_file_op,x               ; Mixed byte
        and     #$0C                            ; Mask load addr high bits
        bpl     osfile_savemixedbyte            ; Always branches (bit 7 clear)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_update_execaddr_xoffset - Update exec address in catalog
; Input: X = catalog offset, aws_tmp00/01 = parameter block pointer
; Translated from MMFS lines 4343-4362
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_update_execaddr_xoffset:
        jsr     remember_axy
        jsr     set_param_block_pointer_b0
        
        ; Copy exec address bytes 0-1 from parameter block to catalog
        ldy     #$06                            ; Param block offset for exec addr
        lda     (aws_tmp00),y
        sta     dfs_cat_file_exec_addr,x        ; MA+&0F0A,X
        iny
        lda     (aws_tmp00),y
        sta     dfs_cat_file_exec_addr+1,x      ; MA+&0F0B,X
        
        ; Update high bits in mixed byte
        iny                                     ; Y=8, high byte of exec addr
        lda     (aws_tmp00),y
        ror     a                               ; Rotate right 3 times to position bits
        ror     a
        ror     a
        eor     dfs_cat_file_op,x               ; Mixed byte
        and     #$C0                            ; Mask exec addr high bits

osfile_savemixedbyte:
        ; Save the updated mixed byte
        eor     dfs_cat_file_op,x
        sta     dfs_cat_file_op,x
        clv                                     ; Clear overflow flag
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_savecat_reta_1 - Save catalog and return A=1
; Common exit point for OSFILE operations that modify catalog
; Translated from MMFS lines 4324-4327
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_savecat_reta_1:
        jsr     save_cat_to_disk
        lda     #$01
        rts
