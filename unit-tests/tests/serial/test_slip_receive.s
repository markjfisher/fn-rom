.export _main
.export t_receive_packet
.export t_receive_packet_end
.export result_len_lo
.export result_len_hi
.export result_checksum_calc
.export result_checksum_wire

.include "fnrom.inc"

result_len_lo       = $2300
result_len_hi       = $2301
result_checksum_calc = $2302
result_checksum_wire = $2303

.code

_main:
        rts

t_receive_packet:
        jsr     fujibus_receive_packet
        sta     result_len_lo
        stx     result_len_hi
        lda     aws_tmp00
        sta     result_checksum_calc
        lda     aws_tmp01
        sta     result_checksum_wire
t_receive_packet_end:
        rts
