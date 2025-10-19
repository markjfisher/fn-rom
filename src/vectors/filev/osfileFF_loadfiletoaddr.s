; OSFILE operation FF - Load file to address
; Handles *LOAD operations
; Translated from MMFS mmfs100.asm lines 1956-1993

        .export osfileFF_loadfiletoaddr
        .export LoadFile_Ycatoffset
        .export LoadMemBlockEX
        .export LoadMemBlock

        .export mjf1

        .import exec_addr_hi2
        .import fuji_read_mem_block
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

        jsr     set_param_block_pointer_b0  ; from catalog
        jsr     read_file_attribs_to_b0_yoffset  ; (Just for info?)

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

        bne     @load_at_load_addr

        ; use load address in control block
        iny
        iny
        ldx     #$02
        bne     @load_copyfileinfo_loop  ; always

        ; use file's load address
@load_at_load_addr:
        lda     dfs_cat_file_op,y               ; mixed byte
        sta     pws_tmp02                       ; C2, used by load_addr_hi2
        jsr     load_addr_hi2

@load_copyfileinfo_loop:
        lda     dfs_cat_file_s1_start,y

        sta     aws_tmp12,x                     ; into &BC,X
        iny
        inx
        cpx     #$08
        bne     @load_copyfileinfo_loop

mjf1:
        nop
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
        jsr     fuji_read_mem_block      ; Read with transaction protection (fuji_fs.s)
        rts
