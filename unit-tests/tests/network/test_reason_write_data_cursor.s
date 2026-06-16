.export _main
.export patch_fujibus_network_write_ext
.export patch_network_flush_write
.export stub_network_flush_write
.export stub_fujibus_network_write_ext
.export t_reason_write_data_cursor_advance
.export t_reason_write_data_cursor_advance_end

.export param_block
.export payload_buf
.export ch1_write_pos_low
.export ch1_write_pos_mid
.export ch1_write_pos_hi
.export ch1_write_count

.include "fnrom.inc"

param_block = $2200
payload_buf = $2300

patch_network_flush_write = network_flush_write + 1
patch_fujibus_network_write_ext = fujibus_network_write_ext + 1

; Channel 1 uses internal channel slot $20.
ch1_write_pos_low = fuji_ch_write_pos_low + $20
ch1_write_pos_mid = fuji_ch_write_pos_mid + $20
ch1_write_pos_hi = fuji_ch_write_pos_hi + $20
ch1_write_count = fuji_ch_write_count + $20

.code

_main:
        rts

stub_network_flush_write:
        lda     #$99
        sta     aws_tmp02
        clc
        rts

stub_fujibus_network_write_ext:
        lda     #$77
        sta     aws_tmp02
        clc
        rts

t_reason_write_data_cursor_advance:
        ldx     #<param_block
        ldy     #>param_block
        jsr     fnnet_dispatch
t_reason_write_data_cursor_advance_end:
        rts
