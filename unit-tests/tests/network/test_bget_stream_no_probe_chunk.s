.export _main
.export patch_fujibus_network_read
.export stub_fujibus_network_read_chunk
.export t_bget_stream_no_probe_chunk
.export t_bget_stream_no_probe_chunk_end

.export call_count
.export result1
.export result2
.export result3
.export result4
.export carry4
.export ch5_bptr_low
.export ch5_bptr_mid
.export ch5_bptr_hi
.export ch5_ext_low
.export ch5_ext_mid
.export ch5_ext_hi
.export ch5_handle_low
.export ch5_handle_high
.export ch5_net_flags
.export ch5_net_proto
.export ch5_buf_page

.include "fnrom.inc"

call_count = $2400
result1 = $2401
result2 = $2402
result3 = $2403
result4 = $2404
carry4 = $2405

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
ch5_net_flags = fuji_ch_net_flags + $A0
ch5_net_proto = fuji_ch_net_proto + $A0
ch5_buf_page = fuji_ch_buf_page + $A0

.code

_main:
        rts

stub_fujibus_network_read_chunk:
        inc     call_count
        lda     #$03
        sta     fuji_network_buf_cnt
        lda     #$00
        sta     fuji_network_buf_cnt_hi
        sta     aws_tmp04
        lda     #'A'
        sta     $2300
        lda     #'B'
        sta     $2301
        lda     #'C'
        sta     $2302
        lda     #$01
        rts

t_bget_stream_no_probe_chunk:
        lda     #$15
        tay
        jsr     bgetv_entry
        sta     result1

        lda     #$15
        tay
        jsr     bgetv_entry
        sta     result2

        lda     #$15
        tay
        jsr     bgetv_entry
        sta     result3

        lda     #$15
        tay
        jsr     bgetv_entry
        sta     result4
        lda     #$00
        adc     #$00
        sta     carry4
t_bget_stream_no_probe_chunk_end:
        rts
