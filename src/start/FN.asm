INCLUDE "build/device.asm"

_ELECTRON_=FALSE        ; Electron version
_MASTER_=FALSE          ; Master version

_SWRAM_=FALSE           ; true = Sideways RAM Version
_BP12K_=FALSE           ; B+ private RAM version

_TUBEHOST_=TRUE         ; Include Tube Host (i.e. no DFS or DFS 0.90)
_VIA_BASE=&FCB0         ; Base Address of 6522 VIA
_TUBE_BASE=&FEE0        ; Base Address of Tube

_DEBUG=FALSE            ; true = enable debugging of service calls, etc
_DEBUG_FN=FALSE         ; true = enable debugging of FN initialization

MACRO BASE_NAME
    EQUS "Model B "
    SYSTEM_NAME
ENDMACRO

INCLUDE "src/fujinet.asm"
