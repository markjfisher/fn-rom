; OSFILE operation 2 - Write load address
; Handles writing load address to existing file
; Translated from MMFS mmfs100.asm lines 4315-4318 (osfile2_wrloadaddr)

        .export osfile2_wrloadaddr

        .import read_fspba_find_cat_entry
        .import osfile_update_loadaddr_xoffset
        .import osfile_savecat_reta_1

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile2_wrloadaddr - Write load address (A=2)
; OSFILE A=2: Write load address to named file's catalog entry
;
; Input: 
;   Filename in parameter block
;   Load address in parameter block bytes 2-5
; Output: 
;   A = 1 (file found and updated)
; Translated from MMFS lines 4315-4318
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile2_wrloadaddr:
        ; Find file in catalog (throws error if not found)
        jsr     read_fspba_find_cat_entry       ; Y=offset, X=offset too
        
        ; Update load address in catalog
        jsr     osfile_update_loadaddr_xoffset
        
        ; Save catalog and return A=1
        jmp     osfile_savecat_reta_1

