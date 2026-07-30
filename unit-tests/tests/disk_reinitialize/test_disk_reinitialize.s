.export _main
.export t_reinitialize_40
.export t_reinitialize_80

.import init_harness

.include "fnrom.inc"

.code

_main:
        rts

t_reinitialize_40:
        lda     #<$0E00
        sta     buffer_ptr
        lda     #>$0E00
        sta     buffer_ptr+1
        lda     #$02
        sta     fuji_disk_slot
        lda     #40
        jsr     fujibus_disk_reinitialize

t_reinitialize_80:
        lda     #<$0E00
        sta     buffer_ptr
        lda     #>$0E00
        sta     buffer_ptr+1
        lda     #$02
        sta     fuji_disk_slot
        lda     #80
        jsr     fujibus_disk_reinitialize
        rts
