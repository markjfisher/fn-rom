.export _main
.export t_exact_first
.export t_exact_first_end
.export t_second_entry
.export t_second_entry_end
.export t_dir_mismatch
.export t_dir_mismatch_end
.export t_wildcard
.export t_wildcard_end
.export t_casefold
.export t_casefold_end
.export result_carry
.export result_y
.export result_done
.export result_offset

result_carry = $2200
result_y = $2201
result_done = $2202
result_offset = $2203

.include "fnrom.inc"

.code

capture_result:
        php
        pla
        and     #$01
        sta     result_carry
        sty     result_y
        lda     aws_tmp06
        sta     result_offset
        lda     #$01
        sta     result_done
        rts

set_defaults_q_drive2:
        lda     #$02
        sta     current_drv
        sta     current_cat
        lda     #'Q'
        sta     directory_param
        lda     #'*'
        sta     fuji_wild_star
        lda     #'#'
        sta     fuji_wild_hash
        rts

set_query_fls:
        lda     #'F'
        sta     fuji_getcat_buf_8+0
        lda     #'L'
        sta     fuji_getcat_buf_8+1
        lda     #'S'
        sta     fuji_getcat_buf_8+2
        lda     #' '
        sta     fuji_getcat_buf_8+3
        sta     fuji_getcat_buf_8+4
        sta     fuji_getcat_buf_8+5
        sta     fuji_getcat_buf_8+6
        sta     fuji_getcat_buf_8+7
        rts

set_query_fls_lower:
        lda     #'f'
        sta     fuji_getcat_buf_8+0
        lda     #'l'
        sta     fuji_getcat_buf_8+1
        lda     #'s'
        sta     fuji_getcat_buf_8+2
        lda     #' '
        sta     fuji_getcat_buf_8+3
        sta     fuji_getcat_buf_8+4
        sta     fuji_getcat_buf_8+5
        sta     fuji_getcat_buf_8+6
        sta     fuji_getcat_buf_8+7
        rts

set_query_flstar:
        lda     #'F'
        sta     fuji_getcat_buf_8+0
        lda     #'L'
        sta     fuji_getcat_buf_8+1
        lda     fuji_wild_star
        sta     fuji_getcat_buf_8+2
        lda     #' '
        sta     fuji_getcat_buf_8+3
        sta     fuji_getcat_buf_8+4
        sta     fuji_getcat_buf_8+5
        sta     fuji_getcat_buf_8+6
        sta     fuji_getcat_buf_8+7
        rts

set_query_fdrive:
        lda     #'F'
        sta     fuji_getcat_buf_8+0
        lda     #'D'
        sta     fuji_getcat_buf_8+1
        lda     #'R'
        sta     fuji_getcat_buf_8+2
        lda     #'I'
        sta     fuji_getcat_buf_8+3
        lda     #'V'
        sta     fuji_getcat_buf_8+4
        lda     #'E'
        sta     fuji_getcat_buf_8+5
        lda     #' '
        sta     fuji_getcat_buf_8+6
        sta     fuji_getcat_buf_8+7
        rts

set_entry0_fls_q:
        lda     #'F'
        sta     dfs_cat_file_name+0
        lda     #'L'
        sta     dfs_cat_file_name+1
        lda     #'S'
        sta     dfs_cat_file_name+2
        lda     #' '
        sta     dfs_cat_file_name+3
        sta     dfs_cat_file_name+4
        sta     dfs_cat_file_name+5
        sta     dfs_cat_file_name+6
        lda     #'Q'
        sta     dfs_cat_file_dir+0
        rts

set_entry0_fls_a:
        jsr     set_entry0_fls_q
        lda     #'A'
        sta     dfs_cat_file_dir+0
        rts

set_entry1_fdrive_q:
        lda     #'F'
        sta     dfs_cat_file_name+8+0
        lda     #'D'
        sta     dfs_cat_file_name+8+1
        lda     #'R'
        sta     dfs_cat_file_name+8+2
        lda     #'I'
        sta     dfs_cat_file_name+8+3
        lda     #'V'
        sta     dfs_cat_file_name+8+4
        lda     #'E'
        sta     dfs_cat_file_name+8+5
        lda     #' '
        sta     dfs_cat_file_name+8+6
        lda     #'Q'
        sta     dfs_cat_file_dir+8
        rts

set_name_ptr_entry0:
        lda     #<dfs_cat_file_name
        sta     aws_tmp06
        lda     #>dfs_cat_file_name
        sta     aws_tmp07
        ldx     #<fuji_getcat_buf_8
        ldy     #$00
        rts

set_name_ptr_entry1:
        lda     #<(dfs_cat_file_name+8)
        sta     aws_tmp06
        lda     #>(dfs_cat_file_name+8)
        sta     aws_tmp07
        ldx     #<fuji_getcat_buf_8
        ldy     #$00
        rts

_main:
        rts

t_exact_first:
        jsr     set_defaults_q_drive2
        jsr     set_query_fls
        jsr     set_entry0_fls_q
        jsr     set_name_ptr_entry0
        lda     #$00
        sta     result_done
        lda     #>(t_exact_first_after - 1)
        pha
        lda     #<(t_exact_first_after - 1)
        pha
        jmp     match_filename
t_exact_first_after:
        jsr     capture_result
t_exact_first_end:
        rts

t_second_entry:
        jsr     set_defaults_q_drive2
        jsr     set_query_fdrive
        jsr     set_entry1_fdrive_q
        jsr     set_name_ptr_entry1
        lda     #$00
        sta     result_done
        lda     #>(t_second_entry_after - 1)
        pha
        lda     #<(t_second_entry_after - 1)
        pha
        jmp     match_filename
t_second_entry_after:
        jsr     capture_result
t_second_entry_end:
        rts

t_dir_mismatch:
        jsr     set_defaults_q_drive2
        lda     #$00
        sta     result_done
        jsr     set_query_fdrive
        jsr     set_entry0_fls_q
        jsr     set_name_ptr_entry0
        lda     #>(t_dir_mismatch_after - 1)
        pha
        lda     #<(t_dir_mismatch_after - 1)
        pha
        jmp     match_filename
t_dir_mismatch_after:
        jsr     capture_result
t_dir_mismatch_end:
        rts

t_wildcard:
        jsr     set_defaults_q_drive2
        lda     #$00
        sta     result_done
        jsr     set_query_fls
        jsr     set_entry0_fls_q
        jsr     set_name_ptr_entry0
        lda     #>(t_wildcard_after - 1)
        pha
        lda     #<(t_wildcard_after - 1)
        pha
        jmp     match_filename
t_wildcard_after:
        jsr     capture_result
t_wildcard_end:
        rts

t_casefold:
        jsr     set_defaults_q_drive2
        lda     #$00
        sta     result_done
        jsr     set_query_fls_lower
        jsr     set_entry0_fls_q
        jsr     set_name_ptr_entry0
        lda     #>(t_casefold_after - 1)
        pha
        lda     #<(t_casefold_after - 1)
        pha
        jmp     match_filename
t_casefold_after:
        jsr     capture_result
t_casefold_end:
        rts
