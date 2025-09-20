        .export cmd_help_fuji
        .export print_help_table

        .import a_rorx4
        .import print_string_ax
        .import print_char
        .import print_newline
        .import remember_axy
        .import rom_title
        .import rom_version_string

        .import parameter_table


        .include "mos.inc"
        .include "fujinet.inc"

        .segment "CODE"

; *HELP FUJI
; this runs into print_help_table, so we can save a byte

cmd_help_fuji:
        tya
        ldx     #cmdtab_offset_fujifs
        ldy     #cmdtab_fujifs_cmds_size

        ; fall through to print_help_table


; A = offset to char on command line (was the Y value from GSINIT)
; X = offset to help for strings for appropriate table (e.g. cmdtab_help_cmds_size)
; Y = function size of table being printed (e.g. cmdtab_offset_help)

print_help_table:
        pha                             ; save 'old Y' from GSINIT so we can restore it later
        stx     aws_tmp15               ; using this as "table offset"
        sty     aws_tmp07               ; using this as "command counter"

        ; Print newline first
        lda     #$0D
        jsr     print_char
        
        ; Print system name and version using ROM header strings
        lda     #<rom_title
        ldx     #>rom_title
        jsr     print_string_ax
        
        ; Print space
        lda     #' '
        jsr     print_char
        
        ; Print version (skip the 0 byte by adding 1 to location)
        lda     #<(rom_version_string + 1)
        ldx     #>(rom_version_string + 1)
        jsr     print_string_ax
        
        ; Print newline
        lda     #$0D
        jsr     print_char
        
        ; now do the commands
@loop:
        lda     #$00
        sta     aws_tmp09               ; ?&B9=0=print command (not error)

        ldy     #$01
        jsr     prtcmd_print_y_spaces_if_not_err
        jsr     prtcmd_at_bc_add_1
        jsr     print_newline
        dec     aws_tmp07
        bne     @loop
        pla
        tay
        ; TODO: we could loop for more printing here...
        rts

prtcmd_at_bc_add_1:
        lda     #$07
        sta     aws_tmp08
        ldx     aws_tmp15

        ; if it's futils, print "F" first, as we only store the strings after the initial letter
        cpx     #<cmdtab_offset_futils
        bne     @cmdloop
        lda     #'F'
        jsr     prtcmd_prtchr
@cmdloop:
        inx
        lda     cmd_table_fujifs,x
        bmi     @cmdloop_exit
        jsr     prtcmd_prtchr
        jmp     @cmdloop

@cmdloop_exit:
        ldy     aws_tmp08
        bmi     @prtcmd_nospcs
        jsr     prtcmd_print_y_spaces_if_not_err
@prtcmd_nospcs:
        stx     aws_tmp15              ; Update table offset for next iteration

        lda     cmd_table_fujifs,x
        and     #$7F
        jsr     @prtcmd_param
        jsr     a_rorx4

@prtcmd_param:
        jsr     remember_axy
        and     #$0F
        beq     @prtcmd_paramexit
        tay
        lda     #' '
        jsr     prtcmd_prtchr
        ldx     #$FF
@prtcmd_findloop:
        inx
        lda     parameter_table,x
        bpl     @prtcmd_findloop
        dey
        bne     @prtcmd_findloop
        and     #$7F
@prtcmd_param_loop:
        jsr     prtcmd_prtchr
        inx
        lda     parameter_table,x
        bpl     @prtcmd_param_loop
        rts

@prtcmd_paramexit:
        rts


prtcmd_prtchr:
        jsr     remember_axy
        ldx     aws_tmp09
        beq     @do_print_char          ; if printing help
        inc     aws_tmp09
        sta     $0100,x
        rts

@do_print_char:
        dec     aws_tmp08
        jmp     print_char

prtcmd_print_y_spaces_if_not_err:
        lda     aws_tmp09
        bne     @exit
        lda     #' '
@loop:
        jsr     prtcmd_prtchr
        dey
        bpl     @loop
@exit:
        rts