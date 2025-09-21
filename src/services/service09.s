; Service call 09 - Help and Service call 04 - Unrecognized Command
        .export service09_help
        .export service04_unrec_command
        .export not_cmd_fs

        .import remember_axy, GSINIT_A, set_text_pointer_yx
        .import print_help_table
        .import cmd_table_fujifs, cmd_table_futils, cmd_table_utils, cmd_table_help, cmd_table_fs
        .import cmd_table_fujifs_cmds, cmd_table_futils_cmds, cmd_table_utils_cmds, cmd_table_help_cmds, cmd_table_fs_cmds

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
        ldx     #cmdtab_offset_fs        ; Start with file system commands

check_command:
        jmp     unrec_command_text_pointer

not_cmd_fs:
        ldx     #cmdtab_offset_utils     ; Try UTILS commands
        bne     check_command


not_cmd_fujifs:
        ldx     #cmdtab_offset_futils    ; Try FUTILS commands
        jsr     GSINIT_A
        lda     (TextPointer),y
        iny
        ora     #$20
        cmp     #'F'
        beq     unrec_command_text_pointer
        dey
        jmp     not_cmd_futils

.fscv3_unreccommand:
        jsr     set_text_pointer_yx
        ldx     #$00
        ; fall through to unrec_command_text_pointer


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; UNRECOGNIZED COMMAND TEXT POINTER
;
; This function tries to match the command line against our command tables.
; X = table offset to start with
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

unrec_command_text_pointer:
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
        lda     cmd_table_fujifs_cmds+1, x
        pha                             ; Push low byte
        rts                             ; Jump to function

@dommcinit:
        ;jsr     MMC_BEGIN2
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