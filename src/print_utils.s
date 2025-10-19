; Print utilities for FujiNet ROM
        .export  err_bad
        .export  err_disk
        .export  print_char
        .export  print_fullstop
        .export  print_hex
        .export  print_newline
        .export  print_nibble
        .export  print_nib_fullstop
        .export  print_space
        .export  print_space_spl
        .export  print_2_spaces_spl
        .export  print_string
        .export  print_string_ax
        .export  print_decimal
        .export  report_error
        .export  report_error_cb

.ifdef FN_DEBUG
        .export  print_axy
        .export  dump_zp_workspace
        .export  dump_memory_block
.endif

        .import  a_rorx4
        .import  clear_exec_spool_file_handle
        .import  osbyte_X0YFF
        .import  remember_axy

        .include "fujinet.inc"

current_cat     = $1082

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; RESET LEDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

reset_leds:
        jsr     remember_axy
        lda     #$76
        jmp     osbyte_X0YFF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ERROR HANDLERS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

err_disk:
        jsr     report_error_cb         ; Disk Error
        .byte   0
        .byte   "Disc "
        bcc     err_continue

err_bad:
        jsr     report_error_cb         ; Bad Error
        .byte   0
        .byte   "Bad "
        bcc     err_continue

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; REPORT ERROR CB
;
; Check if writing channel buffer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

report_error_cb:
        ; TODO: Check if writing channel buffer
        lda     $10DD                   ; Error while writing
        bne     @brk100_notbuf          ; channel buffer?
        jsr     clear_exec_spool_file_handle
@brk100_notbuf:
        lda     #$FF
        sta     current_cat
        sta     $10DD                   ; Not writing buffer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; REPORT ERROR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

report_error:
        ldx     #$02
        lda     #$00                    ; "BRK"
        sta     $0100

err_continue:
        jsr     reset_leds

@report_error2:
        pla                             ; Word cws_tmp7 = Calling address + 1
        sta     cws_tmp7
        pla
        sta     cws_tmp8

        ldy     #$00
        jsr     inc_cws0708_and_load
        sta     $0101                   ; Error number
        dex

@errstr_loop:
        inx
        jsr     inc_cws0708_and_load
        sta     $0100,x
        bmi     print_return2           ; Bit 7 set, return
        bne     @errstr_loop
        ; jsr     tube_release  ; FUTURE: add this back in
        jmp     $0100

; Print newline
print_newline:
        pha
        lda     #$0D
        jsr     print_char
        pla
        rts

; print_nibble_print_string:
;         jsr     print_nibble

; Print a string terminated by bit 7 set (MMFS style)
; String address is on stack, uses ZP $AE $AF $B3
; Exit: AXY preserved, C=0
print_string:
        sta     aws_tmp03               ; Save A
        pla                             ; Get return address
        sta     cws_tmp7
        pla
        sta     cws_tmp8
        lda     aws_tmp03
        pha                             ; Save A & Y
        tya
        pha
        ldy     #0
print_loop:
        jsr     inc_cws0708_and_load
        ; use NOP as a terminator to a string if the next instruction isn't a high byte.
        bmi     print_return1           ; If bit 7 set (end of string)
        jsr     print_char
        bpl     print_loop              ; Always true
print_return1:
        pla                             ; Restore A & Y
        tay
        pla
print_return2:
        clc
        jmp     (cws_tmp7)              ; Return to caller

; Print a string terminated by bit 7 set, or 00 using A/X as address
; A = low byte of string address
; X = high byte of string address
; Exit: AXY preserved
print_string_ax:
        sta     cws_tmp7
        stx     cws_tmp8
        pha                             ; Save A/X/Y
        txa
        pha
        tya
        pha
        ldy     #0
@loop:
        lda     (cws_tmp7),y
        bmi     @done                   ; If bit 7 set (end of string)
        beq     @done                   ; If 00 set (end of string)
        jsr     print_char
        iny
        bne     @loop
@done:
        pla                             ; Restore A/X/Y
        tay
        pla
        tax
        pla
        rts

; Increment word at $AE/cws_tmp07 and load byte
inc_cws0708_and_load:
        inc     cws_tmp7
        bne     @exit
        inc     cws_tmp8
@exit:
        lda     (cws_tmp7),y
        rts

print_2_spaces_spl:
        ; Print two spaces (MMFS Print2SpacesSPL style)
        jsr     print_space_spl
print_space_spl:
        ; Print single space using OSWRCH (MMFS PrintSpaceSPL style)
        pha                             ; Save A
        lda     #' '                    ; Space character
        jsr     OSWRCH                  ; Direct output, no spool manipulation
        pla                             ; Restore A
        clc                             ; C=0
        rts


print_space:
        lda     #' '
        bne     print_char

print_nib_fullstop:
        jsr     print_nibble
print_fullstop:
        lda     #'.'
        ; fall into print_char

; Print a single character
; A = character to print
print_char:
        jsr     remember_axy
        pha
        lda     #$EC                ; OSBYTE 236 - get character destination
        jsr     osbyte_X0YFF

        txa                         ; X contains destination
        pha
        ora     #$10                ; Force bit 4 (disable spooled output)
        tax
        jsr     @osbyte03_Xoutstream ; Disable spooled output

        pla
        tax
        pla
        jsr     OSASCI              ; Output character
        ; Restore previous setting, ... fall through

@osbyte03_Xoutstream:
        lda     #3
        jmp     OSBYTE

print_hex:
        pha
        jsr     a_rorx4         ; rotate in the high nibble
        jsr     print_nibble    ; print the high nibble
        pla                     ; restore so we can print the low nibble
        pha                     ; push again so we can restore
        jsr     print_nibble    ; print the low nibble
        pla                     ; ensure we restore A
        rts

print_nibble:
        jsr     nib_to_asc
        bne     print_char      ; always happens, as nib_to_asc 

nib_to_asc:
        and     #$0F
        cmp     #$0A
        bcc     @nib_asc
        adc     #$06
@nib_asc:
        adc     #$30
        rts

; Print decimal number
; A = number to print (0-99)
print_decimal:
        jsr     remember_axy
        pha
        ; Convert to decimal
        lda     #0
        sta     aws_tmp00              ; Hundreds
        sta     aws_tmp01              ; Tens
        pla
        sta     aws_tmp02              ; Units

        ; Calculate hundreds
@hundreds_loop:
        lda     aws_tmp02
        sec
        sbc     #100
        bcc     @hundreds_done
        sta     aws_tmp02
        inc     aws_tmp00
        jmp     @hundreds_loop

@hundreds_done:
        ; Calculate tens
@tens_loop:
        lda     aws_tmp02
        sec
        sbc     #10
        bcc     @tens_done
        sta     aws_tmp02
        inc     aws_tmp01
        jmp     @tens_loop

@tens_done:
        ; Print hundreds (if any)
        lda     aws_tmp00
        beq     @skip_hundreds
        jsr     print_nibble

@skip_hundreds:
        ; Print tens (if any, or if we printed hundreds)
        lda     aws_tmp00
        bne     @print_tens
        lda     aws_tmp01
        beq     @skip_tens

@print_tens:
        lda     aws_tmp01
        jsr     print_nibble

@skip_tens:
        ; Always print units
        lda     aws_tmp02
        jmp     print_nibble

.ifdef FN_DEBUG
print_axy:
        pha
        jsr     print_string
        .byte   "A="
        nop
        jsr     print_hex

        jsr     print_string
        .byte   ";X="
        txa
        jsr     print_hex

        jsr     print_string
        .byte   ";Y="
        tya
        jsr     print_hex

        jsr     print_newline

        pla
        rts

; Dump ZP workspace areas (A8-CF) as a hex table
; Format:    0  1  2  3  4  5  6  7
;         A8: XX XX XX XX XX XX XX XX
;         B0: XX XX XX XX XX XX XX XX
;         B8: XX XX XX XX XX XX XX XX
;         C0: XX XX XX XX XX XX XX XX
;         C8: XX XX XX XX XX XX XX XX
dump_zp_workspace:
        pha
        txa
        pha
        tya
        pha

        ; Print header row
        jsr     print_string
        .byte   "    0  1  2  3  4  5  6  7", $0D

        ; Dump A8-AF
        lda     #$A8
        jsr     dump_hex_row

        ; Dump B0-B7
        lda     #$B0
        jsr     dump_hex_row

        ; Dump B8-BF
        lda     #$B8
        jsr     dump_hex_row

        ; Dump C0-C7
        lda     #$C0
        jsr     dump_hex_row

        ; Dump C8-CF
        lda     #$C8
        jsr     dump_hex_row

        pla
        tay
        pla
        tax
        pla
        rts

; Dump 8 bytes starting from address in A
; A = start address (e.g., $A8, $B0, etc.)
dump_hex_row:
        jsr     print_hex               ; Print row header (first nibble)
        jsr     print_string
        .byte   ": "
        nop

        ; the above leaves A correct
        tay                             ; Use Y as offset from $A8

        ldx     #0                      ; Loop counter
@loop:
        lda     $A8,y                   ; Load byte using direct addressing
        jsr     print_hex
        jsr     print_space
        iny                             ; Next byte
        inx                             ; Increment counter
        cpx     #8                      ; 8 bytes per row
        bne     @loop

        jsr     print_newline
        rts

; Dump a block of memory
; A = low byte of address
; X = high byte of address  
; Y = number of bytes to dump
dump_memory_block:
        sta     cws_tmp7               ; Store address in ZP
        stx     cws_tmp8
        tya                             ; Save Y (length) to A before pushing anything
        sta     aws_tmp00              ; Store length
        pha                             ; Save A (original A)
        txa
        pha                             ; Save X
        tya
        pha                             ; Save Y (length)

        ldy     #0
@dump_loop:
        lda     (cws_tmp7),y           ; Load byte
        jsr     print_hex              ; Print it
        jsr     print_space            ; Space between bytes
        iny
        cpy     aws_tmp00              ; Compare with saved length
        bne     @dump_loop

        jsr     print_newline
        pla                             ; Restore Y
        tay
        pla                             ; Restore X
        tax
        pla                             ; Restore A
        rts
.endif