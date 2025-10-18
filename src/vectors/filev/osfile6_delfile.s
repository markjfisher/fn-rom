; OSFILE operation 6 - Delete file
; Handles file deletion operations (OSFILE A=6)
; Translated from MMFS mmfs100.asm lines 4301-4305 (osfile6_delfile)

        .export osfile6_delfile

        .import read_fspba_find_cat_entry
        .import check_file_not_locked_or_open_y
        .import delete_cat_entry_yfileoffset
        .import save_cat_to_disk
        .import read_file_attribs_to_b0_yoffset

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile6_delfile - Delete file (A=6)
; OSFILE A=6: Delete named file and return its catalog information
;
; Input: Filename in parameter block
; Output: 
;   A = 1 (file found and deleted)
;   Parameter block updated with deleted file's attributes
; Translated from MMFS lines 4301-4305
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile6_delfile:
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
