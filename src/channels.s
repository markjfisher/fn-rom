;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Channels code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        .export calc_buffer_sector_for_ptr
        .export channel_flags_set_bits
        .export channel_flags_clear_bits
        .export channel_flags_set_bit7
        .export channel_flags_clear_bit7

        .include "fujinet.inc"

        .segment "CODE"

calc_buffer_sector_for_ptr:
        ; Calculate buffer sector for PTR (following MMFS lines 5197-5207)
        clc

        lda     fuji_ch_sec_start,y
        adc     fuji_ch_bptr_mid,y
        sta     pws_tmp03
        sta     fuji_ch_sect_lo,y

        lda     fuji_ch_op,y
        and     #$03
        adc     fuji_ch_bptr_hi,y
        sta     pws_tmp02
        sta     fuji_ch_sect_hi,y

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
