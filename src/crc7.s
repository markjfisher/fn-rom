;        .export vidreset
;        .export check_crc7
;        .export err_bad_sum
;        .export reset_crc7
;        .export calculate_crc7
;
;
;vidreset:
;        ldy     #<(CHECK_CRC7 - VID - 1)
;        lda     #$00
;
;@vr_loop:
;        sta     VID, y
;        dey
;        bpl     @vr_loop
;        lda     #$1
;        sta     CHECK_CRC7
;        rts
;
;check_crc7:
;        jsr     remember_axy
;        jsr     calculate_crc7
;        bne     err_bad_sum
;        rts
;
;err_bad_sum:
;        jsr     err_bad
;        .byte   $FF
;        .byte   "Sum", 0
;
;reset_crc7:
;        jsr     remember_axy
;        jsr     calculate_crc7
;        sta     CHECK_CRC7
;        clc
;        rts
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculate CRC7
;; Exit: A=CRC7, X=0, Y=FF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;calculate_crc7:
;        ldy     #<(CHECK_CRC7 - VID - 1)
;        lda     #$00
;@loop1:
;        eor     VID,y
;        asl     a
;        ldx     #$07
;@loop2:
;        bcc     @c7b7z1
;        eor     #$12
;@c7b7z1:
;        asl     a
;        dex
;        bne     @loop2
;        bcc     @c7b7z2
;        eor     #$12
;@c7b7z2:
;        dey
;        bpl     @loop1
;        ora     #$01
;        rts
;