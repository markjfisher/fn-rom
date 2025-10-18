; OSFILE operation 3 - Write exec address
; Handles writing exec address to existing file
; Translated from MMFS mmfs100.asm lines 4311-4314 (osfile3_wrexecaddr)

        .export osfile3_wrexecaddr

        .import read_fspba_find_cat_entry
        .import osfile_update_execaddr_xoffset
        .import osfile_savecat_reta_1

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile3_wrexecaddr - Write exec address (A=3)
; OSFILE A=3: Write exec address to named file's catalog entry
;
; Input: 
;   Filename in parameter block
;   Exec address in parameter block bytes 6-9
; Output: 
;   A = 1 (file found and updated)
; Translated from MMFS lines 4311-4314
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile3_wrexecaddr:
        ; Find file in catalog (throws error if not found)
        jsr     read_fspba_find_cat_entry       ; Y=offset, X=offset too
        
        ; Update exec address in catalog
        jsr     osfile_update_execaddr_xoffset
        
        ; Save catalog and return A=1
        jmp     osfile_savecat_reta_1

