;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Start of ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ORG     &8000
    GUARD   guard_value

; We aren't a lang
.lang_entry
    BRK
    BRK
    BRK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.service_entry
    JMP     fn_servicecalls

.rom_type
    EQUB    &82
.copyright_offset
    EQUB    LO(copyright-1)
.bin_version
    EQUB    &01
.title
    BUILD_NAME
.version
    BUILD_VERSION
.copyright
    BUILD_COPYRIGHT
.header_end
