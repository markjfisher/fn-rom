INCLUDE "build/device.asm"

_ELECTRON_=FALSE        ; Electron version
_MASTER_=TRUE           ; Master version

_ROMS_=FALSE            ; include *ROMS code
_UTILS_=TRUE            ; include *UTILS code

_SWRAM_=FALSE           ; true = Sideways RAM Version
_BP12K_=FALSE           ; B+ private RAM version

_TUBEHOST_=FALSE        ; Include Tube Host (i.e. no DFS or DFS 0.90)
_TUBE_BASE=&FEE0        ; Base Address of Tube
_DFS_EMUL=TRUE          ; tru = use DFS filesystem number + handles

MACRO BASE_NAME
    EQUS "Master "
    SYSTEM_NAME
ENDMACRO

INCLUDE "src/fujinet.asm"
