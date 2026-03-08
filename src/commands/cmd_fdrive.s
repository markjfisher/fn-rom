        .export cmd_fs_fdrive

        .import fuji_get_mounted_disk
        .import print_char
        .import print_decimal
        .import print_newline
        .import print_space
        .import print_string

        .include "fujinet.inc"

        .segment "CODE"

cmd_fs_fdrive:
        rts
;         jsr     print_newline
;         ldx     #$00
; @loop:
;         txa
;         jsr     print_decimal
;         jsr     print_string
;         .byte   ":", 0
;         jsr     print_space

;         stx     current_drv
;         jsr     fuji_get_mounted_disk
;         cmp     #$FF
;         beq     @empty
;         jsr     print_decimal
;         jmp     @next

; @empty:
;         jsr     print_string
;         .byte   "(empty)", 0

; @next:
;         jsr     print_newline
;         inx
;         cpx     #$04
;         bcc     @loop
;         rts
