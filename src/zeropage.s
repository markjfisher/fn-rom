; zeropage.s — pin cc65’s compiler temps to known ZP addresses

.exportzp  c_sp, sreg, regsave, tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4

ptr1    := $00A8   ; 2 - the one C codegen uses for generic *p stores
sreg    := $00AA   ; 2 - used when 2 indexed operations interact, e.g. foo[x] = bar[y] 
ptr2    := $00AC   ; 2 - haven't seen this used yet

; These are unlikely to be used, we should validate them. There are no CC65 routines being used, just pure C->asm
tmp1    := $00AE   ; 1
tmp2    := $00AF   ; 1

; everything else dump in B0 and validate they are never used
ptr3    := $00B0   ; 2  should never be used
ptr4    := $00B0   ; 2  should never be used
regsave := $00B0   ; 6  should never be used
c_sp    := $00B0   ; 2  should never be used
tmp3    := $00B0   ; 1
tmp4    := $00B0   ; 1
