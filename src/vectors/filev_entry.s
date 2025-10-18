; FILEV_ENTRY - File Vector
; Handles OSFILE calls for file operations like *LOAD, *SAVE, *DELETE, etc.
; Translated from MMFS mmfs100.asm lines 3670-3701

        .export filev_entry

        .import parameter_fsp
        .import print_axy
        .import print_string
        .import remember_axy
        .import osfileFF_loadfiletoaddr
        .import osfile0_savememblock
        .import osfile1_updatecat
        .import osfile2_wrloadaddr
        .import osfile3_wrexecaddr
        .import osfile4_wrattribs
        .import osfile5_rdcatinfo
        .import osfile6_delfile
        .import copy_vars_b0ba
        .import copy_word_b0ba

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILEV_ENTRY - File Vector
; Handles OSFILE calls
; See 16.1.1 of New Advanced User Guide
;
; XY+ is address of the parameter block, whose bytes are:
; 0/1   - address pointing to filename + CR (LSB first)
; 2/5   - load address (32 bit)
; 6/9   - exec address (32 bit)
; 10/13 - start address (32 bit)
; 14/17 - end address (32 bit)
;
; Exit:
; Parameter block is updated by some calls
; A = Undefined unless A was 5:
;     0 = file not found
;     1 = file found
;     2 = dir found
;    FF = if E attribute is set (ADFS only)
; X and Y are unchanged
;
; Actions in A
; Taken from New Advanced User Guide, seems to
; differ to MMFS implementation, see FINV_TABLE
;  
; FF: Load named file, if XY+6 contains 0 use spec. address)
;  0: Save memory block
;  1: Write catalog entry for file 
;  2: Write load address for named file
;  3: Write exec address for named file
;  4: Write file attributes for named file
;  5: Read catalog information
;  6: Delete file, returning catalog information
;  7: Create empty file of defined size (Master only)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

filev_entry:
        dbg_string_axy "FILEV: "
        ; rts

        jsr     remember_axy
        pha
        jsr     parameter_fsp

        stx     aws_tmp00              ; XY -> parameter block
        stx     fuji_param_block_lo    ; Store for later use
        sty     aws_tmp01
        sty     fuji_param_block_hi

        ; Copy parameters from OSFILE call into internal format
        ldx     #$00                   ; BA->filename
        ldy     #$00                   ; BC & 1074=load addr (32 bit)
        jsr     copy_word_b0ba         ; BE & 1076=exec addr
@filev_copyparams_loop:
        jsr     copy_vars_b0ba         ; C0 & 1078=start addr
        cpy     #$12                   ; C2 & 107A=end addr
        bne     @filev_copyparams_loop ; (lo word in zp, hi in page 10)

        pla
        tax
        inx
        cpx     #$08                   ; NB A=FF -> X=0
        bcs     @filev_unknownop       ; IF x>=8 (a>=7)
        lda     finv_table_hi,x        ; get addr from table
        pha                            ; and "return" to it
        lda     finv_table_lo,x
        pha

@filev_unknownop:
        lda     #$00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSFILE operation tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.feature line_continuations +
        ; OSFILE dispatch table - matches MMFS mmfs100.asm lines 4527-4545
        ; Table position -> OSFILE A value mapping:
        ; Position 0: A=$FF (Load file to address)
        ; Position 1: A=$00  (Save memory block)
        ; Position 2: A=$01  (Update catalog entry - load/exec addresses)
        ; Position 3: A=$02  (Write load address)
        ; Position 4: A=$03  (Write exec address)
        ; Position 5: A=$04  (Write file attributes/locked status)
        ; Position 6: A=$05  (Read catalog information)
        ; Position 7: A=$06  (Delete file)

.define FINV_TABLE \
        osfileFF_loadfiletoaddr         - 1, \
        osfile0_savememblock            - 1, \
        osfile1_updatecat               - 1, \
        osfile2_wrloadaddr              - 1, \
        osfile3_wrexecaddr              - 1, \
        osfile4_wrattribs               - 1, \
        osfile5_rdcatinfo               - 1, \
        osfile6_delfile                 - 1

finv_table_lo: .lobytes FINV_TABLE
finv_table_hi: .hibytes FINV_TABLE

.feature line_continuations -
