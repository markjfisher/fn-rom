; OSFILE operation FF - Load file to address
; Handles *LOAD operations
; Translated from MMFS mmfs100.asm lines 1956-1993

        .export osfileFF_loadfiletoaddr
        .export LoadFile_Ycatoffset
        .export LoadMemBlockEX
        .export LoadMemBlock

        .import exec_addr_hi2
        .import fuji_execute_block_rw
        .import fuji_read_catalog
        .import get_cat_entry_fspba
        .import load_addr_hi2
        .import print_axy
        .import print_hex
        .import print_newline
        .import print_string
        .import prt_info_msg_yoffset
        .import read_file_attribs_to_b0_yoffset
        .import set_param_block_pointer_b0

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfileFF_loadfiletoaddr - Load file to address (A=&FF)
; Translated from MMFS lines 1956-1993
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfileFF_loadfiletoaddr:
        jsr     get_cat_entry_fspba        ; Get Load Addr etc.
        bcc     @file_not_found            ; If file not found, exit with error
        
        jsr     set_param_block_pointer_b0  ; from catalogue
        jsr     read_file_attribs_to_b0_yoffset  ; (Just for info?)
        
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "OSFILEFF BE="
        nop
        lda     aws_tmp14
        ldx     #0
        ldy     #0
        jsr     print_axy
.endif
        
        ; Y now contains the catalog offset from get_cat_entry_fspba
        ; Fall into LoadFile_Ycatoffset
        jmp     LoadFile_Ycatoffset

@file_not_found:
        ; File not found - exit with error
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LoadFile_Ycatoffset - Load file at catalog offset Y
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LoadFile_Ycatoffset:
        sty     aws_tmp10                ; STY &BA
        ldx     #$00
        lda     aws_tmp14                ; If ?BE=0 don't do Load Addr
        
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "LOADFILE BE="
        nop
        ldx     #0
        ldy     #0
        jsr     print_axy
.endif
        
        bne     @load_at_load_addr

        ; use load address in control block
        iny
        iny
        ldx     #$02
        bne     @load_copyfileinfo_loop  ; always

        ; use file's load address
@load_at_load_addr:
        lda     $0F0E,y                  ; mixed byte
        sta     pws_tmp02                ; C2, used by load_addr_hi2
        jsr     load_addr_hi2

@load_copyfileinfo_loop:
        lda     $0F08,y
.ifdef FN_DEBUG
        jsr     print_string
        .byte   " COPY "
        nop
        jsr     print_axy
        jsr     print_string
        .byte   " @$0F08,Y ("
        nop
        tya
        jsr     print_hex
        jsr     print_string
        .byte   ") ="
        nop
        lda     $0F08,y
        jsr     print_hex
.endif
        sta     aws_tmp12,x              ; STA &BC,X (same as MMFS)
        iny
        inx
        cpx     #$08
        bne     @load_copyfileinfo_loop

        jsr     exec_addr_hi2

        ldy     aws_tmp10                ; LDY &BA
        jsr     prt_info_msg_yoffset     ; pt. print file info
        ; Fall into LoadMemBlockEX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LoadMemBlockEX - Load memory block
; Since _MM32_ is true and _SWRAM_ is false, lines 1997-2005 are skipped
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LoadMemBlockEX:
        ; Fall into LoadMemBlock

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LoadMemBlock - Load memory block
; FujiNet equivalent - use network read operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LoadMemBlock:
        lda     #$85                     ; Read operation
        jsr     fuji_execute_block_rw
        rts
