.export _main
.export t_load
.export t_load_end

.include "fnrom.inc"

.code

_main:
        rts

t_load:
        jsr     gbpb_load_blkptr
t_load_end:
        rts
