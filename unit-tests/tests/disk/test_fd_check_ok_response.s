.export _main
.export t_check
.export t_check_end

.include "fnrom.inc"

rx_buf = $4000
result = $4100          ; 0 = ok (C clear), 1 = fail (C set)

.code

_main:
        rts

; as a caller does it: A/X = received length, then CMP #minimum
t_check:
        lda     #<rx_buf
        sta     buffer_ptr
        lda     #>rx_buf
        sta     buffer_ptr+1
        lda     $4102           ; received length low
        ldx     $4103           ; received length high
        cmp     $4104           ; minimum
        jsr     fd_check_ok_response
        lda     #$00
        rol     a
        sta     result
t_check_end:
        rts
