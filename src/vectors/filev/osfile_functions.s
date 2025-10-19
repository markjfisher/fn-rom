; OSFILE FUNCTIONS
; All OSFILE operations (A=0 through A=6)
; Translated from MMFS mmfs100.asm lines 2028-2045, 4296-4403

        .export osfile0_savememblock
        .export save_mem_block
        .export osfile1_updatecat
        .export osfile2_wrloadaddr
        .export osfile3_wrexecaddr
        .export osfile4_wrattribs
        .export osfile5_rdcatinfo
        .export osfile6_delfile
        .export osfile_updatelocksavecat
        .export osfile_savecat_reta_1
        .export osfile_update_loadaddr_xoffset
        .export osfile_update_execaddr_xoffset
        .export osfile_updatelock
        .export mjf

        .import check_file_exists
        .import check_file_not_locked
        .import check_file_not_open_y
        .import create_file_fsp
        .import delete_cat_entry_yfileoffset
        .import fuji_execute_block_rw
        .import read_file_attribs_to_b0_yoffset
        .import remember_axy
        .import save_cat_to_disk
        .import set_param_block_pointer_b0

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile0_savememblock - Save memory block (A=0)
; Translated from MMFS lines 2028-2045
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile0_savememblock:
        jsr     create_file_fsp
        jsr     set_param_block_pointer_b0      ; Restore B0 after create_file_fsp
        jsr     read_file_attribs_to_b0_yoffset
        jsr     save_mem_block
mjf:
        lda     #$01                     ; Return A=1 for success (matches MMFS line 2023)
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; save_mem_block - Save block of memory
; FujiNet equivalent - use network write operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

save_mem_block:
        lda     #$A5                     ; Write operation
        jmp     fuji_execute_block_rw    ; Tail call - returns directly to caller

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile5_rdcatinfo - Read catalog information (A=5)
; Translated from MMFS lines 4296-4300
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile5_rdcatinfo:
        jsr     check_file_exists       ; READ CAT INFO
        jsr     read_file_attribs_to_b0_yoffset
        lda     #$01                    ; File type: 1=file found
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile6_delfile - Delete file (A=6)
; Translated from MMFS lines 4301-4305
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile6_delfile:
        jsr     check_file_not_locked   ; DELETE FILE
        jsr     read_file_attribs_to_b0_yoffset
        jsr     delete_cat_entry_yfileoffset
        jmp     osfile_savecat_reta_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile1_updatecat - Update catalog entry (A=1)
; Translated from MMFS lines 4306-4310
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile1_updatecat:
        jsr     check_file_exists       ; UPDATE CAT ENTRY
        jsr     osfile_update_loadaddr_xoffset
        jsr     osfile_update_execaddr_xoffset
        bvc     osfile_updatelocksavecat

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile3_wrexecaddr - Write exec address (A=3)
; Translated from MMFS lines 4311-4314
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile3_wrexecaddr:
        jsr     check_file_exists       ; WRITE EXEC ADDRESS
        jsr     osfile_update_execaddr_xoffset
        bvc     osfile_savecat_reta_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile2_wrloadaddr - Write load address (A=2)
; Translated from MMFS lines 4315-4318
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile2_wrloadaddr:
        jsr     check_file_exists       ; WRITE LOAD ADDRESS
        jsr     osfile_update_loadaddr_xoffset
        bvc     osfile_savecat_reta_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile4_wrattribs - Write file attributes (A=4)
; Translated from MMFS lines 4319-4321
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile4_wrattribs:
        jsr     check_file_exists       ; WRITE ATTRIBUTES
        jsr     check_file_not_open_y
        ; fall through to osfile_updatelocksavecat

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_updatelocksavecat - Update lock and save catalog
; Translated from MMFS lines 4322-4323
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_updatelocksavecat:
        jsr     osfile_updatelock
        ; fall through to osfile_savecat_reta_1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_savecat_reta_1 - Save catalog and return A=1
; Translated from MMFS lines 4324-4327
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_savecat_reta_1:
        jsr     save_cat_to_disk
        lda     #$01
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_update_loadaddr_xoffset - Update load address in catalog
; Translated from MMFS lines 4328-4342
;
; Input: X = catalog offset
;        B0 (aws_tmp00/01) = parameter block pointer (set by filev_entry)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_update_loadaddr_xoffset:
        jsr     remember_axy            ; Update load address
        ldy     #$02
        lda     (aws_tmp00),y           ; Read from parameter block via B0
        sta     dfs_cat_file_load_addr,x        ; MA+&0F08,X
        iny
        lda     (aws_tmp00),y
        sta     dfs_cat_file_load_addr+1,x      ; MA+&0F09,X
        iny
        lda     (aws_tmp00),y
        asl     a
        asl     a
        eor     dfs_cat_file_op,x       ; MA+&0F0E,X
        and     #$0C
        bpl     osfile_savemixedbyte    ; always branches

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_update_execaddr_xoffset - Update exec address in catalog
; Translated from MMFS lines 4343-4362
;
; Input: X = catalog offset
;        B0 (aws_tmp00/01) = parameter block pointer (set by filev_entry)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_update_execaddr_xoffset:
        jsr     remember_axy            ; Update exec address
        ldy     #$06
        lda     (aws_tmp00),y           ; Read from parameter block via B0
        sta     dfs_cat_file_exec_addr,x        ; MA+&0F0A,X
        iny
        lda     (aws_tmp00),y
        sta     dfs_cat_file_exec_addr+1,x      ; MA+&0F0B,X
        iny
        lda     (aws_tmp00),y
        ror     a
        ror     a
        ror     a
        eor     dfs_cat_file_op,x       ; MA+&0F0E,X
        and     #$C0

osfile_savemixedbyte:
        eor     dfs_cat_file_op,x       ; save mixed byte
        sta     dfs_cat_file_op,x
        clv
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_updatelock - Update file locked flag in catalog
; Translated from MMFS lines 4363-4375
;
; Input: X = catalog offset
;        B0 (aws_tmp00/01) = parameter block pointer (set by filev_entry)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_updatelock:
        jsr     remember_axy            ; Update file locked flag
        ldy     #$0E
        lda     (aws_tmp00),y           ; Read attributes from parameter block
        and     #$0A                    ; file attributes AUG pg.336
        beq     osfile_notlocked
        lda     #$80                    ; Lock!

osfile_notlocked:
        eor     dfs_cat_file_dir,x      ; MA+&0E0F,X
        and     #$80
        eor     dfs_cat_file_dir,x
        sta     dfs_cat_file_dir,x
        rts
