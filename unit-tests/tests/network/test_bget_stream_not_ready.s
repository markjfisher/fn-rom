.export _main
.export patch_fujibus_network_read
.export stub_fujibus_network_read_not_ready
.export t_bget_stream_not_ready
.export t_bget_stream_not_ready_end

.export call_count
.export result_a
.export result_c
.export result_p
.export ch5_bptr_low
.export ch5_bptr_mid
.export ch5_bptr_hi
.export ch5_ext_low
.export ch5_ext_mid
.export ch5_ext_hi
.export ch5_handle_low
.export ch5_handle_high
.export ch5_net_proto
.export ch5_buf_start_low
.export ch5_buf_count

.include "fnrom.inc"

call_count = $2400
result_a = $2401
result_c = $2402
result_p = $2403

patch_fujibus_network_read = fujibus_network_read + 1

; Network channel 5 uses internal slot $A0 and BBC file handle $15.
ch5_bptr_low = fuji_ch_bptr_low + $A0
ch5_bptr_mid = fuji_ch_bptr_mid + $A0
ch5_bptr_hi = fuji_ch_bptr_hi + $A0
ch5_ext_low = fuji_ch_ext_low + $A0
ch5_ext_mid = fuji_ch_ext_mid + $A0
ch5_ext_hi = fuji_ch_ext_hi + $A0
ch5_handle_low = fuji_ch_handle_low + $A0
ch5_handle_high = fuji_ch_handle_high + $A0
ch5_net_proto = fuji_ch_net_proto + $A0
ch5_buf_start_low = fuji_ch_1118 + $A0
ch5_buf_count = fuji_ch_sect_cnt + $A0

.code

_main:
        rts

stub_fujibus_network_read_not_ready:
        inc     call_count
        lda     #$02
        rts

t_bget_stream_not_ready:
        lda     #$15
        tay
        jsr     bgetv_entry
        sta     result_a
        lda     #$00
        adc     #$00
        sta     result_c
        php
        pla
        sta     result_p
t_bget_stream_not_ready_end:
        rts
