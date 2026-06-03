; Service call 09 - Help and Service call 04 - Unrecognized Command
        .export fscv3_unreccommand
        .export service04_unrec_command
        .export service09_help
        .export unrec_command_text_pointer
        .export cmd_help_futils
        .export cmd_help_utils
        .export not_cmd_fs
        .export not_cmd_fujifs
        .export help_check_command
        .export unrec_loop_next_command
        .export unrec_loop_match_char
        .export unrec_loop_skip_rest
        .export unrec_loop_end_of_cmd
        .export unrec_dispatch_command
        .export inc_cmd_table_ptr
        .export dec_cmd_table_ptr
        .export read_cmd_table_byte
        .export grp_str_lo
        .export grp_str_hi

        .importzp aws_tmp10
        .importzp aws_tmp11
        .importzp aws_tmp12
        .importzp aws_tmp13
        .importzp aws_tmp14
        .importzp aws_tmp15

        .importzp text_pointer

        .import GSINIT_A
        .import GSREAD_A
        .import is_alpha_char
        .import morehelp
        .import not_cmd_futils
        .import not_cmd_utils
        .import not_cmd_help
        .import print_group_help
        .import remember_axy
        .import set_text_pointer_yx

        ; Command-group table boundaries (see cmd_tables.s / macros.inc cmd_entry).
        .import cmd_str_fujifs
        .import cmd_str_futils
        .import cmd_str_utils
        .import cmd_str_fs
        .import cmd_str_help
        .import cmd_adr_fujifs
        .import cmd_adr_futils
        .import cmd_adr_utils
        .import cmd_adr_fs
        .import cmd_adr_help

.ifdef FN_DEBUG
.endif

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERVICE 09 - HELP
;
; This service is used to print help for the FujiNet ROM.
; It is called when the user types *HELP, or *HELP <command>.
;
; It supports FUJI, UTILS, FUTILS and DFS commands.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service09_help:
        jsr     remember_axy       ; Preserve A, X, Y

        ; Check if this is just *HELP (no arguments)
        ; Y contains offset to first non-space char
        lda     (text_pointer),y         ; Get character at (text_pointer)+Y
        cmp     #$0D                    ; CHR$(13) = carriage return
        bne     help_check_command      ; If not CR, match against *HELP topics

        ; Just *HELP - print the *HELP topic list
        tya                             ; A = offset to first non-space char
        ldx     #cmdtab_group_help
        jmp     print_group_help


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERVICE 04 - UNRECOGNIZED COMMAND
;
; This service is called when an unrecognized command is entered.
; It tries to match the command against our command tables.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service04_unrec_command:
        jsr     remember_axy
        ldx     #cmdtab_group_fs        ; Start with file system commands

check_command:
        jmp     unrec_command_text_pointer

help_check_command:
        ldx     #cmdtab_group_help
        jmp     unrec_command_text_pointer

not_cmd_fs:
.ifndef FUJINET_MACHINE_MASTER

        ldx     #cmdtab_group_utils    ; Try UTILS commands
        bne     check_command           ; Always branch

.else
        rts
.endif


@cmd_not_help_loop:
        jsr     GSREAD_A
        bcc     @cmd_not_help_loop
        jmp     morehelp

not_cmd_fujifs:
        ldx     #cmdtab_group_futils
        jsr     GSINIT_A
        lda     (text_pointer),y
        iny
        ora     #$20                    ; convert to lowercase
        cmp     #'f'                    ; must be lowercase 'f' here. This was a terrible bug to hunt down
        beq     unrec_command_text_pointer
        dey
        jmp     not_cmd_futils


fscv3_unreccommand:
        jsr     set_text_pointer_yx
        ldx     #cmdtab_group_fujifs
        ; fall through to unrec_command_text_pointer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; UNRECOGNIZED COMMAND TEXT POINTER
;
; Match the command line against one command group's table.
; X = group id (cmdtab_group_*). On no match, jumps to the group's not_cmd
; handler (which typically chains to the next group). On match, dispatches the
; handler via the group's CMDADR_<grp> segment.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

unrec_command_text_pointer:
        lda     grp_str_lo,x            ; table pointer = cmd_str_<grp> - 1
        sta     aws_tmp12               ; (the loop leads with an inc)
        lda     grp_str_hi,x
        sta     aws_tmp13
        txa                             ; Save group id on the stack (below the
        pha                             ; command-line position) - the aws_tmp ZP
                                        ; bytes are not safe across GSINIT/GSREAD,
                                        ; but the stack frame is.
        tya                             ; Save incoming command line position
        pha
        lda     #$FF                    ; first inc -> entry index 0
        sta     aws_tmp10

unrec_loop_next_command:
        inc     aws_tmp10               ; Increment command index

        pla                             ; Restore Y
        pha
        tay
        jsr     GSINIT_A                ; Reset text pointer

        ; start looking at the string commands
        jsr     inc_cmd_table_ptr
        jsr     read_cmd_table_byte
        ora     #$00
        beq     unrec_no_match          ; $00 = end of this group's strings

        jsr     dec_cmd_table_ptr       ; Rewind so loop starts on first command char
        dey
        lda     aws_tmp12               ; Save table position for syntax error/help
        sta     aws_tmp14
        lda     aws_tmp13
        sta     aws_tmp15

unrec_loop_match_char:
        jsr     inc_cmd_table_ptr
        iny                             ; Move to next character
        jsr     read_cmd_table_byte
        ora     #$00
        bmi     unrec_loop_end_of_cmd   ; If bit 7 set, end of command

@unrec_loop2in:
        eor     (text_pointer),y        ; Compare with command line, A=00 if they match
        and     #$5F                    ; Ignore case
        beq     unrec_loop_match_char   ; If match, continue

unrec_loop_skip_rest:
        jsr     inc_cmd_table_ptr       ; Skip to end of current command
        jsr     read_cmd_table_byte
        ora     #$00
        bpl     unrec_loop_skip_rest    ; Continue until bit 7 set = command terminator

        ; fall through to unrec_loop_advance_entry
unrec_loop_advance_entry:
        jsr     inc_cmd_table_ptr       ; Skip parameter 1 byte

        lda     (text_pointer),y        ; Check if command line ends with "."
        cmp     #'.'
        bne     unrec_loop_next_command ; If not, try next command
        iny                             ; Skip the "."
        bcs     unrec_dispatch_command

unrec_loop_end_of_cmd:
        lda     (text_pointer),y         ; Check if next char is alphabetic
        jsr     is_alpha_char
        bcc     unrec_loop_advance_entry ; If it is alpha, try next command as it didn't match
        ; end of command match checks against $0D for the CR from command, so falls through...

unrec_dispatch_command:
        pla                             ; discard saved command line position
        pla                             ; recover group id
        tax

        ; Function address comes from the group's CMDADR segment at 2*index.
        ; Y still holds the post-match command-line offset that the handler will
        ; parse its arguments from, so stash it while we use Y to index the table.
        sty     aws_tmp11
        lda     grp_adr_lo,x
        sta     aws_tmp12
        lda     grp_adr_hi,x
        sta     aws_tmp13
        lda     aws_tmp10
        asl     a                       ; Multiply by 2 (addresses are 2 bytes)
        tay
        iny
        lda     (aws_tmp12),y           ; Push high byte of (handler-1)
        pha
        dey
        lda     (aws_tmp12),y           ; Push low byte
        pha
        ldy     aws_tmp11               ; restore command-line offset for the handler
        rts                             ; Jump to function

; No command in this group matched - run the group's not_cmd handler, which
; chains to the next group (or, e.g. for FUTILS, *RUN the command from disk).
unrec_no_match:
        pla                             ; discard saved command line position
        pla                             ; recover group id
        tax
        lda     grp_not_hi,x
        pha
        lda     grp_not_lo,x
        pha
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Per-group descriptors, indexed by group id (cmdtab_group_*):
;   grp_str = first byte of the group's CMDSTR run, minus 1 (loops lead with inc)
;   grp_adr = base of the group's CMDADR run (.word handler-1 per entry)
;   grp_not = not_cmd handler, minus 1 (rts convention), run on no match
; Group id order: fujifs, futils, utils, fs, help.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
grp_str_lo:
        .byte   <(cmd_str_fujifs-1), <(cmd_str_futils-1), <(cmd_str_utils-1), <(cmd_str_fs-1), <(cmd_str_help-1)
grp_str_hi:
        .byte   >(cmd_str_fujifs-1), >(cmd_str_futils-1), >(cmd_str_utils-1), >(cmd_str_fs-1), >(cmd_str_help-1)
grp_adr_lo:
        .byte   <cmd_adr_fujifs, <cmd_adr_futils, <cmd_adr_utils, <cmd_adr_fs, <cmd_adr_help
grp_adr_hi:
        .byte   >cmd_adr_fujifs, >cmd_adr_futils, >cmd_adr_utils, >cmd_adr_fs, >cmd_adr_help
grp_not_lo:
        .byte   <(not_cmd_fujifs-1), <(not_cmd_futils-1), <(not_cmd_utils-1), <(not_cmd_fs-1), <(not_cmd_help-1)
grp_not_hi:
        .byte   >(not_cmd_fujifs-1), >(not_cmd_futils-1), >(not_cmd_utils-1), >(not_cmd_fs-1), >(not_cmd_help-1)

inc_cmd_table_ptr:
        inc     aws_tmp12
        bne     @exit
        inc     aws_tmp13
@exit:
        rts

dec_cmd_table_ptr:
        lda     aws_tmp12
        bne     @dec_lo
        dec     aws_tmp13
@dec_lo:
        dec     aws_tmp12
        rts

read_cmd_table_byte:
        sty     aws_tmp11
        ldy     #$00
        lda     (aws_tmp12),y
        ldy     aws_tmp11
        rts

cmd_help_futils:
        tya
        ldx     #cmdtab_group_futils
        jmp     print_group_help

; THIS NEEDS TO BE IMPLEMENTED CORRECTLY TO DISPLAY THE *HELP UTILS COMMANDS
cmd_help_utils:
        tya
        ldx     #cmdtab_group_utils
        jmp     print_group_help
