.export _main
.export t_receive_to_payload
.export t_receive_to_payload_end
.export result_len_lo
.export result_len_hi
.export result_checksum_calc
.export result_checksum_wire

.include "fnrom.inc"

result_len_lo        = $2308
result_len_hi        = $2309
result_checksum_calc = $230A
result_checksum_wire = $230B

.code

_main:
        rts

t_receive_to_payload:
        jsr     fujibus_receive_packet_to_payload
        sta     result_len_lo
        stx     result_len_hi
        lda     aws_tmp00
        sta     result_checksum_calc
        lda     aws_tmp01
        sta     result_checksum_wire
t_receive_to_payload_end:
        rts
