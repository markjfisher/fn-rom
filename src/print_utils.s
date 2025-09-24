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
        .export  print_string
        .export  print_string_ax

.ifdef FN_DEBUG
        .export  print_axy
.endif

        .import  a_rorx4
        .import  clear_execspool_file_handle
        .import  osbyte_X0YFF
        .import  remember_axy

        .include "mos.inc"

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
        jsr     clear_execspool_file_handle
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
        ; jsr     tube_release  ; TODO: add this back in
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
        lda     cws_tmp3
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
        bmi     @done                   ; If bit 7 set (end of string) - TODO: do we ever use this?
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
        jsr     osbyte03_Xoutstream ; Disable spooled output

        pla
        tax
        pla
        jsr     OSASCI              ; Output character
        ; Restore previous setting, ... fall through

osbyte03_Xoutstream:
        lda     #3
        jmp     OSBYTE

print_hex:
        pha
        jsr     a_rorx4
        jsr     print_nibble
        pla

print_nibble:
        jsr     nib_to_asc
        bne     print_char

nib_to_asc:
        and     #$0F
        cmp     #$0A
        bcc     @nib_asc
        adc     #$06
@nib_asc:
        adc     #$30
        rts

.ifdef FN_DEBUG
print_axy:
        pha
        jsr     print_string
        .byte   "A="
        nop     ; doubles up as end of string AND a nop!
        jsr     print_hex

        jsr     print_string
        .byte   ";X="
        txa
        jsr     print_hex

        jsr     print_string
        .byte   ";Y="
        tya
        jsr     print_hex

        jsr     print_string
        .byte   $0D
        nop

        pla
        rts
.endif