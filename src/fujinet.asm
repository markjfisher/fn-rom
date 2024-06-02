; FujiNet ROM by Mark Fisher (fenrock)
; (c) 2024
;

; beebasm doesn't appear to work in the traditional assemble separate files then link approach, but instead the whole source is defined
; in one large file. however, INCLUDE can be used to emulate the separate functions into files, so I'll be using that to break apart
; the application into manageable chunks.

INCLUDE "src/equates.asm"
INCLUDE "src/rom_entry.asm"

; Everything that other services call
INCLUDE "src/data.asm"
INCLUDE "src/go_fscv.asm"
INCLUDE "src/remember_axy.asm"
INCLUDE "src/utils.asm"
INCLUDE "src/print_string.asm"
INCLUDE "src/workspaces.asm"
INCLUDE "src/channel_flags.asm"
INCLUDE "src/vector_entries.asm"
INCLUDE "src/vectors.asm"

; Command definitions, and init of FujiNet
INCLUDE "src/cmd_fujinet.asm"

; The start of ROM functionality, includes INIT code
INCLUDE "src/service00.asm"

; service definitions
INCLUDE "src/service09_help.asm"

PRINT "    code ends at",~P%,"(",(guard_value - P%), "bytes free)"

SAVE &8000, &C000