.export _main
.export t_read4

.include "fnrom.inc"

.code

_main:
        rts

; OSGBPB 4 (read at PTR) as gbpbv_entry hands it to fastgb
t_read4:
        ldy     #$04
        jmp     fastgb
