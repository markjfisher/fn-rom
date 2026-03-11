; zeropage.s — pin cc65’s compiler temps to known ZP addresses

.exportzp  c_sp, sreg, regsave, tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4

; use pws_tmp14-15 for this, seems not to be touched by anything
c_sp    := $00CE   ; 2

; use aws_tmp00-13 for most cc65 temp regs
; NOTE: these are used by converted MMFS->FujiNet code at the moment, but also as temporary, so before they are refactored
; they should be safe to share locations, as they are by nature temporary.
; OOPS: already discovered C code does a lot of work with ptr1, and aws_tmp00 is used across some functions
ptr1    := $00B0   ; 2 - the one C codegen uses for generic *p stores
ptr2    := $00B2   ; 2 - haven't seen this used yet in simple C apps, but now using general cc65 lib
tmp1    := $00B4   ; 1
tmp2    := $00B5   ; 1
tmp3    := $00B6   ; 1
tmp4    := $00B7   ; 1
ptr3    := $00B8   ; 2
ptr4    := $00BA   ; 2

; skip BC and use CA instead. BC is used in reading blocks of data
sreg    := $00CA   ; 2 - used when 2 indexed operations interact, e.g. foo[x] = bar[y] 

; use cws_tmp5-8, this is used in printing functions print_utils.s as cws0708, but should be fine. regsave unlikely to be used by our ROM
regsave := $00AC   ; 4; AC-AF

;; ALTERNATE CWS/PWS usage - didn't try this, but used above instead
; ; use cws_tmp1-8 for most commonly used values
; ptr1    := $00A8   ; 2 - the one C codegen uses for generic *p stores
; ptr2    := $00AA   ; 2 - haven't seen this used yet in simple C apps, but now using general cc65 lib
; tmp1    := $00AC   ; 1
; tmp2    := $00AD   ; 1
; sreg    := $00AE   ; 2 - used when 2 indexed operations interact, e.g. foo[x] = bar[y] 

; ; use pws_tmp04-13
; tmp3    := $00C4   ; 1
; tmp4    := $00C5   ; 1
; ptr3    := $00C6   ; 2
; ptr4    := $00C8   ; 2

; ; worried about this, clashes with workspace variables used in fs_functions
; ; but potentially should be fine given C code and other ROM code shouldn't mix
; regsave := $00CA   ; 4; CA to CD (tmp10-13)
