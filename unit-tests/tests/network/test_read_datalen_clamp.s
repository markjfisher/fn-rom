.export _main
.export t_read_reply
.export t_read_reply_end

.export reply_buf
.export data_page
.export reply_len_lo
.export reply_len_hi
.export result_a
.export result_cnt
.export ch5_buf_page

.include "fnrom.inc"

; A Read reply is 7 (FujiBus) + 12 (network header) + data bytes, so a chunk
; of 237-255 bytes makes a reply of 256-274 bytes: its length has a high byte.

reply_buf    = $4000                ; the received packet (buffer_ptr)
data_page    = $42                  ; channel buffer page the data is copied to
reply_len_lo = $4400                ; A/X as fujibus_receive_packet returns them
reply_len_hi = $4401
result_a     = $4402
result_cnt   = $4403

; Network channel 5 uses internal slot $A0.
ch5_buf_page = fuji_ch_buf_page + $A0

.code

_main:
        rts

t_read_reply:
        lda     #<reply_buf
        sta     buffer_ptr
        lda     #>reply_buf
        sta     buffer_ptr+1
        lda     #$A0
        sta     fuji_intch
        lda     reply_len_lo
        ldx     reply_len_hi
        jsr     nw_read_after_receive
        sta     result_a
        lda     fuji_network_buf_cnt
        sta     result_cnt
t_read_reply_end:
        rts
