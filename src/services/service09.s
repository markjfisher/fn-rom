; Service call 09 - Help and Service call 04 - Unrecognized Command
        .export fscv3_unreccommand
        .export service04_unrec_command
        .export service09_help
        .export unrec_command_text_pointer
        .export cmd_help_futils
        .export cmd_help_utils

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
        .import morehelp
        .import not_cmd_futils
        .import print_help_table
        .import print_string
        .import remember_axy
        .import set_text_pointer_yx

.ifdef FN_DEBUG
        .import print_axy
.endif

        .include "mos.inc"
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

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: service09", $0D
.endif

        ; Check if this is just *HELP (no arguments)
        ; Y contains offset to first non-space char
        lda     (TextPointer),y         ; Get character at (TextPointer)+Y
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

.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: service04", $0D
        nop
.endif

        ldx     #cmdtab_offset_fs        ; Start with file system commands

check_command:
        jmp     unrec_command_text_pointer

        ldx     #cmdtab_offset_utils     ; Try UTILS commands
        bne     check_command

        ldx     #cmdtab_offset_futils    ; Try FUTILS commands
        jsr     GSINIT_A
        lda     (TextPointer),y
        iny
        ora     #$20
        cmp     #'F'
        beq     unrec_command_text_pointer
        dey
        jmp     not_cmd_futils

@cmd_not_help_loop:
        jsr     GSREAD_A
        bcc     @cmd_not_help_loop
        jmp     morehelp

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
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: unrec_tp", $0D
        ; do 2 so the disassebler aligns
        nop
        nop
        jsr     print_axy
.endif


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
        eor     (TextPointer),y         ; Compare with command line
        and     #$5F                    ; Ignore case
        beq     @unrec_loop2            ; If match, continue
        dex                             ; No match, skip to next command

@unrec_loop3:
        inx                             ; Skip to end of current command
        lda     cmd_table_fujifs, x
        bpl     @unrec_loop3             ; Continue until bit 7 set

        lda     (TextPointer),y         ; Check if command line ends with "."
        cmp     #$2E                    ; Full stop
        bne     @unrec_loop1            ; If not, try next command
        iny                             ; Skip the "."
        bcs     @gocmdcode

@endofcmd_oncmdline:
        lda     (TextPointer),y         ; Check if next char is alphabetic
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


is_alpha_char:
        pha
        and     #$5F
        cmp     #$41
        bcc     @exit1                ; If <"A"
        cmp     #$5B
        bcc     @exit2                ; If <="Z"
@exit1:
        sec
@exit2:
        pla
        rts

cmd_help_futils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: cmd_help_futils", $0D
        nop
.endif
        tya
        ldx     #cmdtab_offset_futils
        ldy     #cmdtab_futils_cmds_size
do_print_help_table:
        jmp     print_help_table

; THIS NEEDS TO BE IMPLEMENTED CORRECTLY TO DISPLAY THE *HELP UTILS COMMANDS
cmd_help_utils:
.ifdef FN_DEBUG
        jsr     print_string
        .byte   "D: cmd_help_utils", $0D
        nop
.endif
        tya
        ldx     #cmdtab_offset_utils
        ldy     #cmdtab_utils_cmds_size
        bne     do_print_help_table
