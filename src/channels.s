;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Channels code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .export channel_flags_set_bits
        .export channel_flags_clear_bits
        .export channel_flags_set_bit7
        .export channel_flags_clear_bit7

        .segment "CODE"

channel_flags_set_bit7:
        lda     #$80
channel_flags_set_bits:
        ora     $1117,y
        bne     channel_flags_save
channel_flags_clear_bit7:
        lda     #$7F
channel_flags_clear_bits:
        and     $1117,y
channel_flags_save:
        sta     $1117,y
        clc
        rts
