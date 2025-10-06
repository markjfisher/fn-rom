; FILEV_ENTRY - File Vector
; Handles OSFILE calls for file operations like *LOAD, *SAVE, *DELETE, etc.
; Translated from MMFS mmfs100.asm lines 3670-3701

        .export filev_entry

        .import remember_axy
        .import parameter_fsp
        .import fuji_read_block
        .import fuji_write_block
        .import fuji_read_catalogue
        .import fuji_write_catalogue

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FILEV_ENTRY - File Vector
; Handles OSFILE calls
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

filev_entry:
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
        lda     finv_tablehi,x         ; get addr from table
        pha                             ; and "return" to it
        lda     finv_tablelo,x
        pha

@filev_unknownop:
        lda     #$00
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSFILE operation tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

finv_tablelo:
        .byte   <(osfileFF_loadfiletoaddr - 1)    ; 0: Load file to address
        .byte   <(osfile0_savememblock - 1)       ; 1: Save memory block
        .byte   <(osfile1_savefile - 1)           ; 2: Save file
        .byte   <(osfile2_deletefile - 1)         ; 3: Delete file
        .byte   <(osfile3_createfile - 1)         ; 4: Create file
        .byte   <(osfile4_writeloadaddr - 1)      ; 5: Write load address
        .byte   <(osfile5_writeexecaddr - 1)      ; 6: Write exec address
        .byte   <(osfile6_writefileattr - 1)      ; 7: Write file attributes

finv_tablehi:
        .byte   >(osfileFF_loadfiletoaddr - 1)    ; 0: Load file to address
        .byte   >(osfile0_savememblock - 1)       ; 1: Save memory block
        .byte   >(osfile1_savefile - 1)           ; 2: Save file
        .byte   >(osfile2_deletefile - 1)         ; 3: Delete file
        .byte   >(osfile3_createfile - 1)         ; 4: Create file
        .byte   >(osfile4_writeloadaddr - 1)      ; 5: Write load address
        .byte   >(osfile5_writeexecaddr - 1)      ; 6: Write exec address
        .byte   >(osfile6_writefileattr - 1)      ; 7: Write file attributes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OSFILE operation handlers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Load file to address (A=&FF)
osfileFF_loadfiletoaddr:
        ; TODO: Implement file loading
        rts

; Save memory block (A=0)
osfile0_savememblock:
        ; TODO: Implement memory block saving
        rts

; Save file (A=1)
osfile1_savefile:
        ; TODO: Implement file saving
        rts

; Delete file (A=2)
osfile2_deletefile:
        ; TODO: Implement file deletion
        rts

; Create file (A=3)
osfile3_createfile:
        ; TODO: Implement file creation
        rts

; Write load address (A=4)
osfile4_writeloadaddr:
        ; TODO: Implement load address writing
        rts

; Write exec address (A=5)
osfile5_writeexecaddr:
        ; TODO: Implement exec address writing
        rts

; Write file attributes (A=6)
osfile6_writefileattr:
        ; TODO: Implement file attribute writing
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Copy word from B0 to BA
copy_word_b0ba:
        ; TODO: Implement word copying
        rts

; Copy variables from B0 to BA
copy_vars_b0ba:
        ; TODO: Implement variable copying
        rts
