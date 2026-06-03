        .export err_cat
        .export fscv5_starCAT

        .importzp aws_tmp06
        .importzp aws_tmp07
        .importzp aws_tmp08

        .importzp current_drv

        .import a_rorx4
        .import current_cat
        .import dfs_cat_boot_option
        .import dfs_cat_cycle
        .import dfs_cat_file_dir
        .import dfs_cat_file_name
        .import dfs_cat_num_x8
        .import dfs_cat_s0_title
        .import dfs_cat_s1_title
        .import fuji_cmd_cat_buf_8
        .import fuji_default_dir
        .import fuji_default_drive
        .import fuji_lib_dir
        .import fuji_lib_drive
        .import fuji_read_catalog
        .import param_optional_drive_no
        .import print_2_spaces_spl
        .import print_char
        .import print_decimal
        .import print_fullstop
        .import print_newline
        .import print_string
        .import prt_filename_yoffset
        .import prt_y_spaces
        .import report_error
        .import set_text_pointer_yx
        .import ucasea2
        .import y_add7
        .import y_add8

        .include "fujinet.inc"

.code

err_cat:
        jsr     report_error
        .byte   $CB
        .byte   "No disk", 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FSCV5_STARCAT - Handle *CAT command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fscv5_starCAT:
        jsr     set_text_pointer_yx
        jsr     param_optional_drive_no
        jsr     fuji_read_catalog
        bmi     err_cat

        ldy     #$FF
        sty     aws_tmp07
        iny
        sty     aws_tmp08

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
        lda     current_drv
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
        bcs     cat_sortloop1                   ; if end of catalog, exit
        lda     dfs_cat_file_dir,y
        eor     fuji_default_dir
        and     #$5F
        bne     cat_curdirnext                  ; if not current directory, skip
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
        sta     current_cat
        ; EXIT with a final new line.
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
        sty     aws_tmp06
        ldx     #$00
@cat_copyfnloop:
        lda     dfs_cat_file_name,y
        jsr     ucasea2
        sta     fuji_cmd_cat_buf_8,x
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
        sbc     fuji_cmd_cat_buf_8,x
        dey
        dex
        bpl     @cat_comparefnloop2
        jsr     y_add7
        lda     dfs_cat_file_dir,y
        jsr     ucasea2
        sbc     fuji_cmd_cat_buf_8 + 7
        bcc     cat_printfilename
        jsr     y_add8
        bcs     @cat_comparefnloop1
cat_printfn:
        ldy     aws_tmp06
        lda     dfs_cat_file_name,y
        ora     #$80
        sta     dfs_cat_file_name,y
        lda     fuji_cmd_cat_buf_8 + 7
        cmp     aws_tmp08
        beq     cat_samedir
        ldx     aws_tmp08
        sta     aws_tmp08
        bne     cat_samedir
        jsr     print_newline           ; 2 newlines after default dir
cat_newline:
        jsr     print_newline
        ldy     #$FF
        bne     cat_skipspaces
cat_samedir:
        ldy     aws_tmp07
        bne     cat_newline
        ldy     #$05                    ; print column gap
        jsr     prt_y_spaces
cat_skipspaces:
        iny
        sty     aws_tmp07
        ldy     aws_tmp06
        jsr     print_2_spaces_spl
        jsr     prt_filename_yoffset
        jmp     cat_sortloop1


; ALLOCATE IN RODATA FOR STRINGS
.rodata

; 4 byte strings, short ones terminate with 0,
diskoptions_table:
        .byte   "off", 0
        .byte   "LOAD"
        .byte   "RUN", 0
        .byte   "EXEC"
