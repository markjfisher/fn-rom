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
        .export set_cmd_table_ptr_x
        .export inc_cmd_table_ptr
        .export dec_cmd_table_ptr
        .export read_cmd_table_byte

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
        .import print_help_table
        .import remember_axy
        .import set_text_pointer_yx

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

        lda     #<cmd_table_help
        sta     aws_tmp14
        lda     #>cmd_table_help
        sta     aws_tmp15
        tya                             ; Y contains offset to first non-space char
        ldy     #cmdtab_help_cmds_size
        ; Just *HELP - print basic help
        jmp     print_help_table


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SERVICE 04 - UNRECOGNIZED COMMAND
;
; This service is called when an unrecognized command is entered.
; It tries to match the command against our command tables.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service04_unrec_command:
        jsr     remember_axy
        ldx     #cmdtab_offset_fs        ; Start with file system commands

check_command:
        jmp     unrec_command_text_pointer

help_check_command:
        ldx     #cmdtab_offset_help
        jmp     unrec_command_text_pointer

not_cmd_fs:
        ldx     #cmdtab_offset_utils    ; Try UTILS commands
        bne     check_command           ; Always branch

@cmd_not_help_loop:
        jsr     GSREAD_A
        bcc     @cmd_not_help_loop
        jmp     morehelp

not_cmd_fujifs:
        ldx     #cmdtab_offset_futils
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
        ldx     #$00
        ; fall through to unrec_command_text_pointer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; UNRECOGNIZED COMMAND TEXT POINTER
;
; This function tries to match the command line against the command tables.
; X = offset to first byte of cmd table, e.g. cmdtab_offset_futils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

unrec_command_text_pointer:
        jsr     set_cmd_table_ptr_x
        tya                             ; Save incoming command line position before clobbering Y
        pha
        ldy     #$00
        lda     (aws_tmp12),y
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
        beq     unrec_dispatch_command  ; If end of table

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
        jsr     inc_cmd_table_ptr       ; Skip parameter 2 byte so next loop lands on next command

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
        pla                             ; Clean up stack

        ; Calculate function address
        lda     aws_tmp10
        asl     a                       ; Multiply by 2 (addresses are 2 bytes)
        tax
        lda     cmd_table_fujifs_cmds+1, x

        pha                             ; Push high byte
        lda     cmd_table_fujifs_cmds, x
        pha                             ; Push low byte
        rts                             ; Jump to function

set_cmd_table_ptr_x:
        cpx     #cmdtab_offset_utils
        beq     @utils
        cpx     #cmdtab_offset_fs
        beq     @fs
        cpx     #cmdtab_offset_help
        beq     @help
        cpx     #cmdtab_offset_futils
        beq     @futils
        lda     #<cmd_table_fujifs
        ldx     #>cmd_table_fujifs
        bne     @store
@utils:
        lda     #<cmd_table_utils
        ldx     #>cmd_table_utils
        bne     @store
@fs:
        lda     #<cmd_table_fs
        ldx     #>cmd_table_fs
        bne     @store
@help:
        lda     #<cmd_table_help
        ldx     #>cmd_table_help
        bne     @store
@futils:
        lda     #<cmd_table_futils
        ldx     #>cmd_table_futils
@store:
        sta     aws_tmp12
        stx     aws_tmp13
        rts

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
        lda     #<cmd_table_futils
        sta     aws_tmp14
        lda     #>cmd_table_futils
        sta     aws_tmp15
        tya
        ldy     #cmdtab_futils_cmds_size
do_print_help_table:
        jmp     print_help_table

; THIS NEEDS TO BE IMPLEMENTED CORRECTLY TO DISPLAY THE *HELP UTILS COMMANDS
cmd_help_utils:
        lda     #<cmd_table_utils
        sta     aws_tmp14
        lda     #>cmd_table_utils
        sta     aws_tmp15
        tya
        ldy     #cmdtab_utils_cmds_size
        bne     do_print_help_table
