.export _main
.export t_total
.export t_total_end
.export pkt_buf

.include "fnrom.inc"

pkt_buf = $4000

.code

_main:
        rts

t_total:
        lda     #<pkt_buf
        sta     buffer_ptr
        lda     #>pkt_buf
        sta     buffer_ptr+1
        jsr     fujibus_send_packet_scatter_store_total_len
t_total_end:
        rts
