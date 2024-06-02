; FujiNet ROM by Mark Fisher (fenrock)
; (c) 2024
;

; beebasm doesn't appear to work in the traditional assemble separate files then link approach, but instead the whole source is defined
; in one large file. however, INCLUDE can be used to emulate the separate functions into files, so I'll be using that to break apart
; the application into manageable chunks.

INCLUDE "src/equates.asm"
INCLUDE "src/rom_entry.asm"

; Functions that other services call
INCLUDE "src/go_fscv.asm"
INCLUDE "src/remember_axy.asm"

; The start of ROM functionality, includes INIT code
INCLUDE "src/fn_service_calls.asm"

; service definitions
INCLUDE "src/service09_help.asm"

PRINT "    code ends at",~P%," (",(guard_value - P%), "bytes free )"

SAVE &8000, &C000