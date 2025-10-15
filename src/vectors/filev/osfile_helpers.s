; OSFILE helper functions
; Common utility functions used by OSFILE operations

        .export set_param_block_pointer_b0
        .export load_addr_hi2
        .export exec_addr_hi2
        .export create_file_fsp
        .export copy_vars_b0ba
        .export copy_word_b0ba
        .export read_fspba_find_cat_entry
        .export debug_here
        .export create_file_2
        .export create_file_3
        .export cfile_copyfnloop
        .export cfile_atcatentry

        .import a_rorx4and3
        .import a_rorx6and3
        .import check_file_not_locked_or_open_y
        .import err_disk
        .import get_cat_firstentry80
        .import get_cat_firstentry80_fname
        .import load_cur_drv_cat2
        .import prt_info_msg_yoffset
        .import read_fspba_reset
        .import report_error_cb
        .import save_cat_to_disk
        .import y_add8
        .import y_sub8
.ifdef FN_DEBUG
        .import print_axy
        .import print_string
        .import print_hex
        .import print_newline
.endif

        .include "fujinet.inc"

        .segment "CODE"


read_fspba_find_cat_entry:
        jsr     read_fspba_reset
        jsr     get_cat_firstentry80
        bcc     check_exit
        tya
        tax
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; set_param_block_pointer_b0 - Set parameter block pointer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

set_param_block_pointer_b0:
        lda     fuji_param_block_lo
        sta     aws_tmp00
        lda     fuji_param_block_hi
        sta     aws_tmp01
check_exit:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; load_addr_hi2 - Load address high bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load_addr_hi2:
        lda     #$00
        sta     $1075                    ; MA+&1075
        lda     pws_tmp02                ; &C2
        and     #$08
        sta     $1074                    ; MA+&1074
        beq     ldadd_nothost
set_load_addr_to_host:
        lda     #$FF
        sta     $1075                    ; MA+&1075
        sta     $1074                    ; MA+&1074
ldadd_nothost:
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; exec_addr_hi2 - Execution address high bits
; Translated from MMFS lines 2642-2655
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load_and_execute_addr_hi2:
        jsr     load_addr_hi2

exec_addr_hi2:
        lda     #$00
        sta     fuji_buf_1077            ; MA+&1077
        lda     pws_tmp02                ; &C2
        jsr     a_rorx6and3              ; Shift right 6 bits and mask with 3
        cmp     #$03
        bne     @exadd_nothost
        lda     #$FF
        sta     fuji_buf_1077            ; MA+&1077
@exadd_nothost:
        sta     fuji_buf_1076            ; MA+&1076
        rts


err_disk_full:
        jsr     err_disk
        .byte   $C6
        .byte   "full",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; create_file_fsp - Create file from FSP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

create_file_fsp:
        jsr     read_fspba_reset
        jsr     get_cat_firstentry80
        bcc     @create_file_nodel

        jsr     delete_cat_entry_yfileoffset

@create_file_nodel:
        lda     pws_tmp00
        pha
        lda     pws_tmp01
        pha
        sec
        lda     pws_tmp02                ; A=1078/C1/C0=start address
        sbc     pws_tmp00                ; B=107A/C3/C2=end address
        sta     pws_tmp00                ; C=C4/C1/C0=file length
        lda     pws_tmp03
        sbc     pws_tmp01
        sta     pws_tmp01
        lda     fuji_buf_107A
        sbc     fuji_buf_1078

        jsr     create_file_2
        lda     fuji_buf_1079            ; Load Address=Start Address
        sta     fuji_buf_1075            ; 4 bytes
        lda     fuji_buf_1078
        sta     fuji_buf_1074
        pla
        sta     aws_tmp13
        pla
        sta     aws_tmp12
        rts

create_file_3:
        sta     CurrentDrv
        lda     DirectoryParam
        pha
        jsr     load_cur_drv_cat2
        jsr     get_cat_firstentry80_fname
        bcc     cd_writedest_cat_nodel
        jsr     delete_cat_entry_yfileoffset
cd_writedest_cat_nodel:
        pla
        sta     DirectoryParam
        jsr     load_and_execute_addr_hi2
        lda     pws_tmp02
        jsr     a_rorx4and3

create_file_2:
        sta     pws_tmp04
        lda     #$00
        sta     pws_tmp02
        lda     #$02
        sta     pws_tmp03
        lda     dfs_cat_num_x8
        cpy     #$F8
        bcc     getfirstblock_yoffset

err_cat_full:
        jsr     report_error_cb
        .byte   $BE
        .byte   "Cat full",0

cfile_loop:
        beq     err_disk_full
        jsr     y_sub8

        lda     dfs_cat_file_op,y
        jsr     a_rorx4and3
        sta     pws_tmp02

        clc
        lda     #$FF
        adc     dfs_cat_file_size,y

        lda     dfs_cat_file_sect,y
        adc     dfs_cat_file_size+1,y
        sta     pws_tmp03

        lda     dfs_cat_file_op,y
        and     #$03
        adc     pws_tmp02
        sta     pws_tmp02

getfirstblock_yoffset:
        sec
        lda     dfs_cat_sect_count,y
        sbc     pws_tmp03
        pha
        lda     dfs_cat_boot_option,y
        and     #$03
        sbc     pws_tmp02
        tax
        lda     #$00
        cmp     pws_tmp00
        pla
        sbc     pws_tmp01
        txa
        sbc     pws_tmp04

        tya
        bcc     cfile_loop
        sty     aws_tmp00
        ldy     dfs_cat_num_x8
@cfile_insertfileloop:
        cpy     aws_tmp00
        beq     cfile_atcatentry
        lda     dfs_cat_s0_title+7,y
        sta     dfs_cat_file_dir,y
        lda     dfs_cat_sect_count,y     ; Load from 0F07+Y 
        sta     dfs_cat_file_sect,y     ; Store to 0F0F+Y (shift by 8)
        dey
        bcs     @cfile_insertfileloop
cfile_atcatentry:
        lda     fuji_buf_1076,y
        and     #$03
        asl     a
        asl     a
        eor     pws_tmp04
        and     #$FC
        eor     pws_tmp04
        asl     a
        asl     a
        eor     fuji_buf_1074           ; Load address
        and     #$FC
        eor     fuji_buf_1074
        asl     a
        asl     a
        eor     pws_tmp02               ; Sector
        and     #$FC
        eor     pws_tmp02
        sta     pws_tmp02               ; C2 is mixed byte

        ldx     #$00
        tya
        pha
cfile_copyfnloop:
.ifdef FN_DEBUG_CREATE_FILE
        cpx     #0
        bne     @skip_debug
        ; Mark catalog copy start - store load address low byte
        lda     aws_tmp12
        sta     $6FF1               ; Debug marker - load address low
        lda     aws_tmp12+1  
        sta     $6FF2               ; Debug marker - load address high
@skip_debug:
.endif
        lda     pws_tmp05,x             ; Copy filename from &C5
        sta     dfs_cat_file_name,y
        lda     aws_tmp12,x             ; Copy attributes
        sta     dfs_cat_file_load_addr,y
        iny
        inx
        cpx     #$08
        bne     cfile_copyfnloop
        pla
        tay
        pha
        jsr     prt_info_msg_yoffset

        ldy     dfs_cat_num_x8

        jsr     y_add8
        sty     dfs_cat_num_x8

debug_here:
.ifdef FN_DEBUG_CREATE_FILE
        ; Mark before catalog save
        lda     #$CC
        sta     $6FF4               ; Debug marker - before save
.endif
        jsr     save_cat_to_disk
        pla
        tay
        rts


delete_cat_entry_yfileoffset:
        jsr     check_file_not_locked_or_open_y

@del_cat_loop:
        lda     dfs_cat_file_name+8,y
        sta     dfs_cat_file_name,y
        lda     dfs_cat_file_load_addr+8,y
        sta     dfs_cat_file_load_addr,y
        iny
        cpy     dfs_cat_num_x8
        bcc     @del_cat_loop
        tya
        sbc     #$08
        sta     dfs_cat_num_x8
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; copy_vars_b0ba - Copy variables from B0 to BA
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

copy_vars_b0ba:
        jsr     copy_word_b0ba
        dex
        dex
        jsr     @copy_byte
@copy_byte:
        lda     (aws_tmp00),y
        sta     $1072,x                 ; TODO: what is this?
        inx
        iny
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; copy_word_b0ba - Copy word from B0 to BA
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

copy_word_b0ba:
        jsr     @copy_byte
@copy_byte:
        lda     (aws_tmp00),y
        sta     aws_tmp10,x
        inx
        iny
        rts
