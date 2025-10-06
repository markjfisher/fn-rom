; FILEV_ENTRY - File Vector
; Handles OSFILE calls for file operations like *LOAD, *SAVE, *DELETE, etc.
; Translated from MMFS mmfs100.asm lines 3670-3701

        .export filev_entry

        .import parameter_fsp
        .import remember_axy
        .import osfileFF_loadfiletoaddr
        .import osfile0_savememblock
        .import osfile1_savefile
        .import osfile2_deletefile
        .import osfile3_createfile
        .import osfile4_writeloadaddr
        .import osfile5_writeexecaddr
        .import osfile6_writefileattr
        .import copy_vars_b0ba
        .import copy_word_b0ba

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILEV_ENTRY - File Vector
; Handles OSFILE calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

filev_entry:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "FILEV "
        nop
        jsr     print_axy
.endif
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

        ; 0: Load file to address (A=&FF)
        ; 1: Save memory block (A=0)
        ; 2: Save file (A=1)
        ; 3: Delete file (A=2)
        ; 4: Create file (A=3)
        ; 5: Write load address (A=4)
        ; 6: Write exec address (A=5)
        ; 7: Write file attributes (A=6)

.define FINV_TABLE \
        osfileFF_loadfiletoaddr         - 1, \
        osfile0_savememblock            - 1, \
        osfile1_savefile                - 1, \
        osfile2_deletefile              - 1, \
        osfile3_createfile              - 1, \
        osfile4_writeloadaddr           - 1, \
        osfile5_writeexecaddr           - 1, \
        osfile6_writefileattr           - 1

finv_table_lo: .lobytes FINV_TABLE
finv_table_hi: .hibytes FINV_TABLE

.feature line_continuations -
