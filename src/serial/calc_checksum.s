; calc_checksum:
;   Input:  aws_tmp00/01 = buf (pointer)
;           aws_tmp02/03 = len (16-bit)
;   Output: A = (uint8_t)chk    ; also stores final 16-bit chk in aws_tmp04/05
;   Clobbers: A, Y, amends ZP locations aws_tmp00-04
;
; ZP usage:
;   aws_tmp04 = checksum

        .export  _calc_checksum

        .import  inc_word_aws_tmp00_dec_word_aws_tmp02

        .include "fujinet.inc"

; This effectively does the following checksum calculation
;
; for (int i = 0; i < len; i++)
;   chk = ((chk + buf[i]) >> 8) + ((chk + buf[i]) & 0xff);
;
; Note that (chk + buf[i]) is bounded from 0 to $1FE (FF+FF), so the sum of the two
; halves of the sum can never be over $FF (max: 1+FE), so always fits in 1 byte.

_calc_checksum:
        ; chk = 0
        lda     #$00
        sta     aws_tmp04

        ; if len == 0 -> return 0
        lda     aws_tmp02
        ora     aws_tmp03
        beq     @exit           ; A is already 0, can exit straight out with result of 0

        ldy     #$00            ; Y stays 0 for (buf),Y
@loop:
        lda     (aws_tmp00),y

        ; this whittles down to chk = (chk + new byte) + (carry from the addition)
        clc
        adc     aws_tmp04
        adc     #$00               ; deal with carry by adding it back in, this never overflows, see comments above
        sta     aws_tmp04          ; new checksum

        jsr     inc_word_aws_tmp00_dec_word_aws_tmp02
        bne     @loop

        lda     aws_tmp04          ; return checksum
@exit:
        rts
