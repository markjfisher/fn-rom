;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Channels code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .export channel_flags_set_bits
        .export channel_flags_clear_bits
        .export channel_flags_set_bit7
        .export channel_flags_clear_bit7

        .include "fujinet.inc"

        .segment "CODE"

channel_flags_set_bit7:
        lda     #$80
channel_flags_set_bits:
        ora     fuji_ch_flg,y
        bne     channel_flags_save
channel_flags_clear_bit7:
        lda     #$7F
channel_flags_clear_bits:
        and     fuji_ch_flg,y
channel_flags_save:
        sta     fuji_ch_flg,y
        clc
        rts
