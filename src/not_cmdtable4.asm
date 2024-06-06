.NotCmdTable4

IF _DEBUG
    JSR     PrintString
    EQUB    "NCT4 "
    NOP
    JSR     PrintAXY
ENDIF

    RTS
