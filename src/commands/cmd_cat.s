        .export fscv5_starCAT

        ;; exports for debugging
        ; .export cat_curdirloop
        ; .export cat_curdirnext
        ; .export cat_exit
        ; .export cat_getnextunmarkedfile_loop
        ; .export cat_getnextunmarkedfileY
        ; .export cat_newline
        ; .export cat_printfilename
        ; .export cat_printfn
        ; .export cat_printoptionnameloop
        ; .export cat_samedir
        ; .export cat_skipspaces
        ; .export cat_sortloop1
        ; .export cat_titleloop
        ; .export cat_titlelo
        ; .export end_title

        .import a_rorx4
        .import fuji_read_catalog
        .import param_optional_drive_no
        .import print_2_spaces_spl
        .import print_axy
        .import print_char
        .import print_decimal
        .import print_fullstop
        .import print_newline
        .import print_space
        .import print_string
        .import prt_filename_yoffset
        .import prt_y_spaces
        .import set_text_pointer_yx
        .import ucasea2
        .import y_add7
        .import y_add8


        .include "fujinet.inc"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV5_STARCAT - Handle *CAT command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv5_starCAT:
        ; dbg_string_axy "FSCV5_STARCAT: "

        jsr     set_text_pointer_yx
        jsr     param_optional_drive_no         ; we need to check if this works with FujiNet impl
        jsr     fuji_read_catalog

        ldy     #$FF
        sty     cws_tmp1
        iny
        sty     cws_tmp3

cat_titleloop:
        lda     dfs_cat_s0_title,y
        cpy     #$08
        bcc     cat_titlelo
        lda     dfs_cat_s1_title-8,y
cat_titlelo:
        ; terminate at first space - assumes no spaces in title
        cmp     #' '
        beq     end_title

        jsr     print_char
        iny
        cpy     #$0C
        bne     cat_titleloop

end_title:
        jsr     print_string
        .byte   " ("
        lda     dfs_cat_cycle
        jsr     print_decimal
        jsr     print_string
        .byte   ")", $0D, "Drive "
        lda     CurrentDrv
        jsr     print_decimal

        ldy     #13
        jsr     prt_y_spaces
        jsr     print_string
        .byte   "Option "
        lda     dfs_cat_boot_option
        jsr     a_rorx4
        pha
        jsr     print_decimal
        jsr     print_string
        .byte   " ("
        ldy     #$03
        pla
        asl     a
        asl     a
        tax
cat_printoptionnameloop:
        lda     diskoptions_table,x
        jsr     print_char
        inx
        dey
        bpl     cat_printoptionnameloop
        jsr     print_string
        .byte   ")", $0D, "Dir. :"
        lda     fuji_default_drive
        jsr     print_decimal
        jsr     print_fullstop
        lda     fuji_default_dir
        jsr     print_char

        ldy     #11
        jsr     prt_y_spaces
        jsr     print_string
        .byte   "Lib. :"
        lda     fuji_lib_drive
        jsr     print_decimal
        jsr     print_fullstop

        lda     fuji_lib_dir
        jsr     print_char
        jsr     print_newline

        ldy     #$00
cat_curdirloop:
        cpy     dfs_cat_num_x8
        bcs     cat_sortloop1                  ; if end of catalog, exit
        lda     dfs_cat_file_dir,y
        eor     fuji_default_dir
        and     #$5F
        bne     cat_curdirnext                 ; if not current directory, skip
        lda     dfs_cat_file_dir,y              ; set directory to null
        and     #$80                            ; keep locked flag (bit 7)
        sta     dfs_cat_file_dir,y
cat_curdirnext:
        jsr     y_add8
        bcc     cat_curdirloop
cat_sortloop1:
        ldy     #$00
        jsr     cat_getnextunmarkedfileY
        bcc     cat_printfilename
        lda     #$FF
        sta     CurrentCat
        jmp     print_newline
cat_getnextunmarkedfile_loop:
        jsr     y_add8
cat_getnextunmarkedfileY:
        cpy     dfs_cat_num_x8
        bcs     cat_exit
        lda     dfs_cat_file_name,y
        bmi     cat_getnextunmarkedfile_loop
cat_exit:
        rts

cat_printfilename:
        sty     cws_tmp4
        ldx     #$00
@cat_copyfnloop:
        lda     dfs_cat_file_name,y
        jsr     ucasea2
        sta     fuji_buf_1060,x
        iny
        inx
        cpx     #$08
        bne     @cat_copyfnloop
@cat_comparefnloop1:
        jsr     cat_getnextunmarkedfileY
        bcs     cat_printfn
        sec
        ldx     #$06
@cat_comparefnloop2:
        lda     dfs_cat_file_name+$06,y
        jsr     ucasea2
        sbc     fuji_buf_1060,x
        dey
        dex
        bpl     @cat_comparefnloop2
        jsr     y_add7
        lda     dfs_cat_file_dir,y
        jsr     ucasea2
        sbc     fuji_buf_1067
        bcc     cat_printfilename
        jsr     y_add8
        bcs     @cat_comparefnloop1
cat_printfn:
        ldy     cws_tmp4
        lda     dfs_cat_file_name,y
        ora     #$80
        sta     dfs_cat_file_name,y
        lda     fuji_buf_1067
        cmp     cws_tmp3
        beq     cat_samedir
        ldx     cws_tmp3
        sta     cws_tmp3
        bne     cat_samedir
        jsr     print_newline           ; 2 newlines after default dir
cat_newline:
        jsr     print_newline
        ldy     #$FF
        bne     cat_skipspaces
cat_samedir:
        ldy     cws_tmp1
        bne     cat_newline
        ldy     #$05                    ; print column gap
        jsr     prt_y_spaces
cat_skipspaces:
        iny
        sty     cws_tmp1
        ldy     cws_tmp4
        jsr     print_2_spaces_spl
        jsr     prt_filename_yoffset
        jmp     cat_sortloop1


; 4 byte strings, short ones terminate with 0,
diskoptions_table:
        .byte   "off", 0
        .byte   "LOAD"
        .byte   "RUN", 0
        .byte   "EXEC"