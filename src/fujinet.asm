; FujiNet ROM by Mark Fisher (fenrock)
; (c) 2024
;

; beebasm doesn't appear to work in the traditional assemble separate files then link approach, but instead the whole source is defined
; in one large file. however, INCLUDE can be used to emulate the separate functions into files, so I'll be using that to break apart
; the application into manageable chunks.

INCLUDE "src/equates.asm"
INCLUDE "src/rom_entry.asm"

; Everything that other services call
; there is some minor order dependency here, e.g. vectors have to be after vector_entries. This is true of any data references.
INCLUDE "src/data.asm"
INCLUDE "src/remember_axy.asm"
INCLUDE "src/utils.asm"
INCLUDE "src/errors.asm"
INCLUDE "src/print_string.asm"
INCLUDE "src/workspaces.asm"
INCLUDE "src/channel_flags.asm"
INCLUDE "src/vector_entries.asm"
INCLUDE "src/vector_fscv.asm"
INCLUDE "src/vector_fns/unimplemented.asm"
INCLUDE "src/not_cmdtable4.asm"

; Command definitions, and init of FujiNet/Disk/Disc
INCLUDE "src/cmd_fujinet_disc.asm"

; Group the HELP entries as they rely on function in cmd_help_fujinet
INCLUDE "src/cmds/cmd_help_fujinet.asm"
INCLUDE "src/cmds/cmd_futils.asm"
INCLUDE "src/cmds/cmd_utils.asm"

INCLUDE "src/cmds/cmd_close.asm"
INCLUDE "src/cmds/cmd_copy.asm"
INCLUDE "src/cmds/cmd_delete.asm"
INCLUDE "src/cmds/cmd_dir.asm"
INCLUDE "src/cmds/cmd_fboot.asm"
INCLUDE "src/cmds/cmd_fcat.asm"
INCLUDE "src/cmds/cmd_fdir.asm"
INCLUDE "src/cmds/cmd_fdrive.asm"
INCLUDE "src/cmds/cmd_fin.asm"
INCLUDE "src/cmds/cmd_drive.asm"
INCLUDE "src/cmds/cmd_info.asm"
INCLUDE "src/cmds/cmd_lib.asm"
INCLUDE "src/cmds/cmd_roms.asm"

; after commands
INCLUDE "src/cmds/print_fns.asm"
INCLUDE "src/cmd_tables.asm"
INCLUDE "src/vector_tables.asm"


; KEEP THESE IN ORDER GIVEN
; The start of ROM functionality, includes INIT code
INCLUDE "src/service00.asm"
INCLUDE "src/service01_claim_absworkspace.asm"
INCLUDE "src/service02_claim_privworkspace.asm"
INCLUDE "src/service03_autoboot.asm"
INCLUDE "src/service04_unrec_command.asm"
INCLUDE "src/service08_unrec_osword.asm"
INCLUDE "src/service0a_claim_statworkspace.asm"

; service definitions
INCLUDE "src/service09_help.asm"

INCLUDE "src/fujinet_bus.asm"

PRINT "    code ends at",~P%,"(",(guard_value - P%), "bytes free)"

SAVE &8000, &C000