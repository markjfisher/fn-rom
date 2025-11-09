; calc_checksum:
;   Input:  aws_tmp00/01 = buf (pointer)
;           aws_tmp02/03 = len (16-bit)
;   Output: A = (uint8_t)chk    ; also stores final 16-bit chk in aws_tmp04/05
;   Clobbers: A, Y
;
; ZP usage:
;   aws_tmp00 = buf lo
;   aws_tmp01 = buf hi
;   aws_tmp02 = len lo
;   aws_tmp03 = len hi
;   aws_tmp04 = chk lo
;   aws_tmp05 = chk hi

        .export  _calc_checksum
        .include "fujinet.inc"

_calc_checksum:
        stx     aws_tmp02
        sty     aws_tmp03

        ; chk = 0
        lda     #$00
        sta     aws_tmp04
        sta     aws_tmp05

        ; if len == 0 -> return 0
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @done

        ldy     #$00          ; Y stays 0 for (buf),Y

@loop:
        ; b = *buf
        lda     (aws_tmp00),y

        ; tmp_lo = chk_lo + b
        clc
        adc     aws_tmp04
        sta     aws_tmp04          ; chk_lo = tmp_lo

        ; tmp_hi = chk_hi + carry
        lda     aws_tmp05
        adc     #$00               ; A = tmp_hi

        ; chk = tmp_lo + tmp_hi
        clc
        adc     aws_tmp04          ; A = tmp_hi + tmp_lo
        sta     aws_tmp04          ; chk_lo = sum low
        lda     #$00
        adc     #$00               ; A = carry (0 or 1)
        sta     aws_tmp05          ; chk_hi = carry

        ; ++buf
        inc     aws_tmp00
        bne     @buf_no_hi
        inc     aws_tmp01
@buf_no_hi:

        ; --len (16-bit), and loop if not zero
        lda     aws_tmp02
        bne     @dec_low
        dec     aws_tmp03
        beq     @done              ; high reached 0 after borrow -> finished
        dec     aws_tmp02          ; set low to $FF (we borrowed)
        jmp     @loop

@dec_low:
        dec     aws_tmp02
        jmp     @loop

@done:
        lda     aws_tmp04          ; return low byte of chk
        rts
