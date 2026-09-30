.export _main
.export t_done
.export r_full_sector
.export r_short
.export r_none
.export r_long_low_byte
.export r_bad_status

.import init_harness

.include "fnrom.inc"

; Calls fd_check_ok_response the way its callers do: A/X = received length,
; then cmp #minimum. Stores the returned carry (1 = fail) at `result`.
.macro check len, minimum, result
        lda     #<len
        ldx     #>len
        cmp     #minimum
        jsr     fd_check_ok_response
        lda     #$00
        rol     a
        sta     result
.endmacro

.code

_main:
        lda     #<rx
        sta     buffer_ptr
        lda     #>rx
        sta     buffer_ptr+1
        lda     #$01                    ; one status param
        sta     rx+5
        lda     #$00                    ; status Ok
        sta     rx+6
        lda     #$2C                    ; a sector read's tail byte count
        sta     aws_tmp14

        check   $0112, $12, r_full_sector       ; 256-byte sector reply
        check   $0006, $07, r_short             ; shorter than the minimum
        check   $0000, $07, r_none              ; no packet
        check   $0105, $12, r_long_low_byte     ; over 256: low byte doesn't matter
        lda     #$05                            ; status IOError
        sta     rx+6
        check   $0112, $12, r_bad_status
t_done:
        rts

; CODE is writable RAM in the harness.
rx:             .res 8
r_full_sector:  .byte $FF
r_short:        .byte $FF
r_none:         .byte $FF
r_long_low_byte: .byte $FF
r_bad_status:   .byte $FF
