; OSFILE operation 4 - Write file attributes
; Handles writing file attributes (locked/unlocked status)
; Translated from MMFS mmfs100.asm lines 4319-4375 (osfile4_wrattribs + osfile_updatelock)

        .export osfile4_wrattribs
        .export osfile_updatelocksavecat
        .export osfile_updatelock

        .import read_fspba_find_cat_entry
        .import check_file_not_open_y
        .import save_cat_to_disk
        .import remember_axy

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile4_wrattribs - Write file attributes (A=4)
; OSFILE A=4: Write file attributes (locked status) to catalog entry
;
; Input: 
;   Filename in parameter block
;   Attributes in parameter block byte 14 (bit 1 = locked)
; Output: 
;   A = 1 (file found and updated)
; Translated from MMFS lines 4319-4321
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile4_wrattribs:
        ; Find file in catalog (throws error if not found)
        jsr     read_fspba_find_cat_entry       ; Y=offset, X=offset too
        
        ; Check file is not currently open
        jsr     check_file_not_open_y
        
        ; Fall through to update lock status and save catalog

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_updatelocksavecat - Update lock status and save catalog
; Translated from MMFS lines 4322-4327
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_updatelocksavecat:
        jsr     osfile_updatelock
        
        ; Fall through to save catalog and return A=1
        ; (Could use BVC but fall-through is clearer)
        jsr     save_cat_to_disk
        lda     #$01
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile_updatelock - Update file locked flag in catalog
; Updates the locked bit (bit 7) of the file's sector/flags byte
;
; Input: X = file offset in catalog
; Uses: Parameter block byte 14 (attributes)
; Translated from MMFS lines 4363-4375
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile_updatelock:
        jsr     remember_axy            ; Save registers
        
        ; Read attributes byte from parameter block
        ldy     #$0E                    ; Offset to attributes in param block
        lda     (aws_tmp00),y           ; B0 points to param block
        and     #$0A                    ; Check bits 1 and 3 (locked flags)
        beq     @osfile_notlocked
        lda     #$80                    ; Set lock bit
        
@osfile_notlocked:
        ; Update lock bit in catalog (EOR/AND/EOR pattern preserves other bits)
        eor     dfs_cat_file_sect,x     ; XOR with current value
        and     #$80                    ; Mask to lock bit only
        eor     dfs_cat_file_sect,x     ; XOR again to set/clear lock bit
        sta     dfs_cat_file_sect,x     ; Store back to catalog
        rts

