; Service call 09 - Help and Service call 04 - Unrecognized Command
        .export fscv3_unreccommand
        .export service04_unrec_command
        .export service09_help
        .export unrec_command_text_pointer
        .export cmd_help_futils
        .export cmd_help_utils
        .export not_cmd_fs
        .export not_cmd_fujifs

        .import GSINIT_A
        .import GSREAD_A
        .import cmd_table_fs
        .import cmd_table_fs_cmds
        .import cmd_table_fujifs
        .import cmd_table_fujifs_cmds
        .import cmd_table_futils
        .import cmd_table_futils_cmds
        .import cmd_table_help
        .import cmd_table_help_cmds
        .import cmd_table_utils
        .import cmd_table_utils_cmds
        .import is_alpha_char
        .import morehelp
        .import not_cmd_futils
        .import print_help_table
        .import print_string
        .import remember_axy
        .import set_text_pointer_yx

.ifdef FN_DEBUG
        .import print_axy
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

        dbg_string_axy "service09: "

        ; Check if this is just *HELP (no arguments)
        ; Y contains offset to first non-space char
        lda     (text_pointer),y         ; Get character at (text_pointer)+Y
        ldx     #cmdtab_offset_help
        cmp     #$0D                    ; CHR$(13) = carriage return
        bne     check_command           ; If not CR, check for command

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

        dbg_string_axy "service04: "

        ldx     #cmdtab_offset_fs        ; Start with file system commands

check_command:
        jmp     unrec_command_text_pointer

not_cmd_fs:

        dbg_string_axy "NOT_CMD_FS: "

        ldx     #cmdtab_offset_utils    ; Try UTILS commands
        bne     check_command           ; Always branch

@cmd_not_help_loop:
        jsr     GSREAD_A
        bcc     @cmd_not_help_loop
        jmp     morehelp

not_cmd_fujifs:

        dbg_string_axy "NOT_CMD_FUJIFS: "

        ldx     #cmdtab_offset_futils
        jsr     GSINIT_A
        lda     (text_pointer),y
        iny
        ora     #$20
        cmp     #'F'
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
        dbg_string_axy "unrec_tp: "


        lda     cmd_table_fujifs, x
        sta     aws_tmp14
        tya                             ; Save Y (command line position)
        pha

@unrec_loop1:
        inc     aws_tmp14               ; Increment command index

        pla                             ; Restore Y
        pha
        tay
        jsr     GSINIT_A                ; Reset text pointer

        ; start looking at the string commands
        inx
        lda     cmd_table_fujifs, x
        beq     @gocmdcode               ; If end of table

        dex
        dey
        stx     aws_tmp15               ; Save table position for syntax error

@unrec_loop2:
        inx
        iny                             ; Move to next character
        lda     cmd_table_fujifs, x
        bmi     @endofcmd_oncmdline      ; If bit 7 set, end of command

@unrec_loop2in:
        eor     (text_pointer),y         ; Compare with command line
        and     #$5F                    ; Ignore case
        beq     @unrec_loop2            ; If match, continue
        dex                             ; No match, skip to next command

@unrec_loop3:
        inx                             ; Skip to end of current command
        lda     cmd_table_fujifs, x
        bpl     @unrec_loop3             ; Continue until bit 7 set

        lda     (text_pointer),y         ; Check if command line ends with "."
        cmp     #$2E                    ; Full stop
        bne     @unrec_loop1            ; If not, try next command
        iny                             ; Skip the "."
        bcs     @gocmdcode

@endofcmd_oncmdline:
        lda     (text_pointer),y         ; Check if next char is alphabetic
        jsr     is_alpha_char
        bcc     @unrec_loop1             ; If not alpha, try next command

@gocmdcode:
        pla                             ; Clean up stack

        ; Calculate function address
        lda     aws_tmp14
        asl     a                       ; Multiply by 2 (addresses are 2 bytes)
        tax
        lda     cmd_table_fujifs_cmds+1, x
        bpl     @dommcinit

@gocmdcode2:
        pha                             ; Push high byte
        lda     cmd_table_fujifs_cmds, x
        pha                             ; Push low byte
        rts                             ; Jump to function

@dommcinit:
        ;jsr     MMC_BEGIN2 ; TODO do we need this?
        ora     #$80
        bne     @gocmdcode2

cmd_help_futils:
        dbg_string_axy "cmd_help_futils: "
        tya
        ldx     #cmdtab_offset_futils
        ldy     #cmdtab_futils_cmds_size
do_print_help_table:
        jmp     print_help_table

; THIS NEEDS TO BE IMPLEMENTED CORRECTLY TO DISPLAY THE *HELP UTILS COMMANDS
cmd_help_utils:
        dbg_string_axy "cmd_help_utils: "
        tya
        ldx     #cmdtab_offset_utils
        ldy     #cmdtab_utils_cmds_size
        bne     do_print_help_table
