; entry routines for the vector overrides

.ARGSV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "ARGSV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}
.BGETV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "BGETV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}
.BPUTV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "BPUTV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}
.FILEV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "FILEV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}
.FINDV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "FINDV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}

.GBPBV_ENTRY
{
IF _DEBUG
    JSR     PrintString
    EQUB    "GBPBV "
    NOP
    JSR     PrintAXY
ENDIF

	RTS
}
