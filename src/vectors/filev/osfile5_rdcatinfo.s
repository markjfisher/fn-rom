; OSFILE operation 5 - Read catalog information
; Handles reading file information from catalog without modifying it
; Translated from MMFS mmfs100.asm lines 4296-4300 (osfile5_rdcatinfo)

        .export osfile5_rdcatinfo

        .import read_fspba_find_cat_entry
        .import read_file_attribs_to_b0_yoffset

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile5_rdcatinfo - Read catalog information (A=5)
; OSFILE A=5: Read file attributes from catalog into parameter block
;
; Input: 
;   Filename in parameter block
; Output: 
;   A = 1 (file found)
;   Parameter block updated with:
;     - Load address (bytes 2-5)
;     - Exec address (bytes 6-9)
;     - File length (bytes 10-13)
;     - File attributes (byte 14)
; Translated from MMFS lines 4296-4300
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile5_rdcatinfo:
        ; Find file in catalog (throws error if not found)
        jsr     read_fspba_find_cat_entry       ; Y=offset, X=offset too
        
        ; Read file attributes into parameter block
        jsr     read_file_attribs_to_b0_yoffset
        
        ; Return file type: 1=file found
        lda     #$01
        rts

