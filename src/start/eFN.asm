INCLUDE "build/device.asm"

_ELECTRON_=TRUE         ; Electron version
_MASTER_=FALSE          ; Master version

_ROMS_=FALSE            ; include *ROMS code
_UTILS_=TRUE            ; include *UTILS code

_SWRAM_=FALSE           ; true = Sideways RAM Version
_BP12K_=FALSE           ; B+ private RAM version

_TUBEHOST_=TRUE         ; Include Tube Host (i.e. no DFS or DFS 0.90)
_VIA_BASE=&FCB0         ; Base Address of 6522 VIA
_TUBE_BASE=&FCE0        ; Base Address of Tube
_DFS_EMUL=TRUE          ; tru = use DFS filesystem number + handles

MACRO BASE_NAME
    EQUS "Electron "
    SYSTEM_NAME
ENDMACRO

INCLUDE "src/fujinet.asm"
