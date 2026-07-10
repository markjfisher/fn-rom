; Compatibility stub. Path resolution now lives in FujiNet-NIO and is performed
; by FileDevice/FujiDevice/DiskDevice handlers using AppStore current-host state.
        .export  flist_resolve_target

        .segment "CODE"

flist_resolve_target:
        sec
        rts
