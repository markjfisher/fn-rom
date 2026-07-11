        .export cmd_help_fuji
        .export morehelp
        .export not_cmd_help
        .export print_group_help
        .export prtcmd_at_bc_add_1
        .export prtcmd_prtchr
        .export help_print_loop
        .export help_print_done
        .export help_cmdloop
        .export help_cmdloop_exit
        .export help_print_params
        .export help_param_entry
        .export help_param_findloop
        .export help_param_printloop
        .export help_inc_table_ptr

        .importzp aws_tmp08
        .importzp aws_tmp09
        .importzp aws_tmp10
        .importzp aws_tmp14
        .importzp aws_tmp15

        .import GSINIT_A
        .import GSREAD_A
        .import grp_str_lo
        .import grp_str_hi
        .import parameter_table
        .import print_char
        .import print_newline
        .import print_string_ax
        .import remember_axy
        .import rom_title
        .import rom_version_string
        .import unrec_command_text_pointer

        .include "fujinet.inc"

        .segment "CODE"

; *HELP FUJI
cmd_help_fuji:
        tya                             ; A = saved command-line offset
        ldx     #cmdtab_group_fujifs
        ; fall through to print_group_help


; Print every command in one group, one per line, with its parameter hints.
; Entry: X = group id (cmdtab_group_*)
;        A = command-line offset to restore into Y on exit
; The group is walked from cmd_str_<grp> to its $00 terminator; the "F" prefix
; is added for the FUTILS group.

print_group_help:
        pha                             ; save command-line offset
        txa
        eor     #cmdtab_group_futils    ; 0 means add F prefix to each entry.
        sta     aws_tmp10
        lda     grp_str_lo,x            ; table pointer = cmd_str_<grp> - 1
        sta     aws_tmp14               ; (the print loop leads with an inc)
        lda     grp_str_hi,x
        sta     aws_tmp15

        jsr     print_newline

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

        jsr     print_newline

        ; now do the commands
help_print_loop:
        lda     #$00
        sta     aws_tmp09               ; ?&B9=0=print command (not error)

        ldy     #$01
        jsr     prtcmd_print_y_spaces_if_not_err
        jsr     prtcmd_at_bc_add_1
        jsr     print_newline

        ; another command? aws_tmp14/15 now points at this entry's param2 byte;
        ; the byte after it is the next command's first char, or the $00 terminator.
        ldy     #$01
        lda     (aws_tmp14),y
        bne     help_print_loop
help_print_done:
        pla
        tay
        rts

; this is equivalent of CMD_NOTHELPTBL
not_cmd_help:
        jsr     GSINIT_A
        bne     @not_cmd_help_loop
        rts
@not_cmd_help_loop:
        jsr     GSREAD_A
        bcc     @not_cmd_help_loop
        ; fall through to morehelp

morehelp:
        ldx     #cmdtab_group_help
        jmp     unrec_command_text_pointer

prtcmd_at_bc_add_1:
        lda     #$07
        sta     aws_tmp08

        lda     aws_tmp10
        bne     help_cmdloop
        lda     #'F'
        jsr     prtcmd_prtchr
help_cmdloop:
        jsr     inc_help_table_ptr
        ldy     #$00
        lda     (aws_tmp14),y
        bmi     help_cmdloop_exit
        jsr     prtcmd_prtchr
        jmp     help_cmdloop

help_cmdloop_exit:
        ldy     aws_tmp08
        bmi     help_print_params
        jsr     prtcmd_print_y_spaces_if_not_err
help_print_params:
        ldy     #$00
        lda     (aws_tmp14),y
        and     #$7F                    ; preserve param 1 while stripping end-of-command marker
        jsr     help_param_entry
        iny
        lda     (aws_tmp14),y
        jsr     help_param_entry
        jsr     inc_help_table_ptr
        rts

help_param_entry:
        beq     help_param_exit
        tay
        txa
        pha
        lda     #' '
        jsr     prtcmd_prtchr
        ldx     #$FF
help_param_findloop:
        inx
        lda     parameter_table,x
        bpl     help_param_findloop
        dey
        bne     help_param_findloop
        and     #$7F
help_param_printloop:
        jsr     prtcmd_prtchr
        inx
        lda     parameter_table,x
        bpl     help_param_printloop
        pla
        tax
        rts

help_param_exit:
        rts

inc_help_table_ptr:
help_inc_table_ptr:
        inc     aws_tmp14
        bne     @exit
        inc     aws_tmp15
@exit:
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
