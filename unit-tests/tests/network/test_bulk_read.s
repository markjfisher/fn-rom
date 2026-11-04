.export _main, call_bulk, end_bulk, block, stub_not_ready
.include "fnrom.inc"
block=$2200
.code
_main: rts
call_bulk:
    ldx #<block
    ldy #>block
    jsr fnnet_dispatch
end_bulk: rts
stub_not_ready:
    lda #2
    rts

.export test_fuji_ch_ext_low
test_fuji_ch_ext_low=fuji_ch_ext_low+$A0

.export test_fuji_ch_handle_high
test_fuji_ch_handle_high=fuji_ch_handle_high+$A0

.export test_fuji_ch_handle_low
test_fuji_ch_handle_low=fuji_ch_handle_low+$A0

.export test_fuji_ch_net_flags
test_fuji_ch_net_flags=fuji_ch_net_flags+$A0

.export test_fuji_ch_bptr_low
test_fuji_ch_bptr_low=fuji_ch_bptr_low+$A0

.export test_fuji_ch_net_proto
test_fuji_ch_net_proto=fuji_ch_net_proto+$A0

.export test_fuji_ch_1118
test_fuji_ch_1118=fuji_ch_1118+$A0

.export test_fuji_ch_buf_page
test_fuji_ch_buf_page=fuji_ch_buf_page+$A0

.export block1
block1=block+1

.export block7
block7=block+7

.export block8
block8=block+8

.export init_case, end_init
init_case:
    lda #8
    sta fuji_open_channels
    lda #1
    sta test_fuji_ch_handle_low
    sta test_fuji_ch_handle_high
    lda #4
    sta test_fuji_ch_net_proto
    lda #$10
    sta test_fuji_ch_net_flags
    lda #$23
    sta test_fuji_ch_buf_page
    lda #0
    sta fuji_ch_bptr_low+$A0
    sta fuji_ch_bptr_mid+$A0
    sta fuji_ch_bptr_hi+$A0
    sta fuji_ch_1118+$A0
    lda #$FF
    sta fuji_ch_ext_low+$A0
    sta fuji_ch_ext_mid+$A0
    sta fuji_ch_ext_hi+$A0
    sta fuji_ch_sect_cnt+$A0
    ldx #0
@fill:
    txa
    sta $2300,x
    lda #$CC
    sta $2500,x
    inx
    bne @fill
    lda #$A5
    sta $24FF
    ldx #15
@block:
    lda initial_block,x
    sta block,x
    dex
    bpl @block
end_init: rts
initial_block: .byte 7,$AA,0,$25,1,0,$15,$AA,$AA,0,0,0,0,0,0,0
.export capacity
capacity=block+4
.export call_legacy, end_legacy
call_legacy:
    lda #0
    sta block+1
    sta block+7
    ldx #0
@next:
    ldy #$15
    jsr bgetv_entry
    bcs end_legacy
    sta $2500,x
    inx
    cpx capacity
    bne @next
    stx block+8
end_legacy: rts
.export patch_read, buffer_count, pointer_mid, pointer_hi
patch_read=fujibus_network_read+1
buffer_count=fuji_ch_sect_cnt+$A0
pointer_mid=fuji_ch_bptr_mid+$A0
pointer_hi=fuji_ch_bptr_hi+$A0
.export call_bulk512, end_bulk512, refill_count, stub_refill
refill_count=$2700
stub_refill:
    inc refill_count
    lda #255
    sta fuji_network_buf_cnt
    lda #0
    sta fuji_network_buf_cnt_hi
    lda #4
    sta aws_tmp04 ; MORE_AVAILABLE: do not impose a no-probe boundary
    lda #1
    rts
call_bulk512:
    lda #0
    sta refill_count
    lda #255
    sta capacity
    jsr call_bulk
    lda #7
    sta block
    lda #$FF
    sta block+2
    jsr call_bulk
    lda #7
    sta block
    lda #$FE
    sta block+2
    lda #$26
    sta block+3
    lda #2
    sta capacity
    jsr call_bulk
end_bulk512: rts

.export block3, block4, block5, block6, block9
block3=block+3
block4=block+4
block5=block+5
block6=block+6
block9=block+9
