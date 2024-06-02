; Vector table copied to &0212
.vectors_table
    EQUW &FF1B    ; FILEV
    EQUW &FF1E    ; ARGSV
    EQUW &FF21    ; BGETV
    EQUW &FF24    ; BPUTV
    EQUW &FF27    ; GBPBV
    EQUW &FF2A    ; FINDV
    EQUW &FF2D    ; FSCV

; Extended vector table
.extendedvectors_table
    EQUW FILEV_ENTRY
    BRK
    EQUW ARGSV_ENTRY
    BRK
    EQUW BGETV_ENTRY
    BRK
    EQUW BPUTV_ENTRY
    BRK
    EQUW GBPBV_ENTRY
    BRK
    EQUW FINDV_ENTRY
    BRK
    EQUW FSCV_ENTRY
    BRK

