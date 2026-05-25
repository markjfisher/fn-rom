REM filename: o78call
REM
REM ----------------------------------------------------
REM OSWORD &78 BOOTSTRAP THEN ROM CALL TEST
REM ----------------------------------------------------
REM Step 1: Call OSWORD &78 with reason 0 to fetch the FujiNet
REM entry point.
REM Step 2: Call that entry point directly with reason 0 again.
REM This separates service 08 handling from the ROM API entry.

finOsword%=&78
finMosOsword%=&FFF1
finReasonVersion%=0

DIM finBoot% 16
DIM finCall% 16

CLS
PRINT "FujiNet OSWORD then CALL test"
PRINT

PROCclear(finBoot%)
finBoot%?0=finReasonVersion%

A%=finOsword%
X%=finBoot% MOD 256
Y%=finBoot% DIV 256
CALL finMosOsword%

entry%=finBoot%?8+256*finBoot%?9
PROCdump("OSWORD result",finBoot%)

IF finBoot%?1<>0 PRINT "Bootstrap failed":END
IF entry%=0 PRINT "No entry returned":END

PROCclear(finCall%)
finCall%?0=finReasonVersion%

A%=finReasonVersion%
X%=finCall% MOD 256
Y%=finCall% DIV 256
CALL entry%

PROCdump("Direct CALL result",finCall%)

END

DEF PROCclear(block%)
FOR I%=0 TO 15
?(block%+I%)=0
NEXT
ENDPROC

DEF PROCdump(label$,block%)
PRINT label$
PRINT "Status  : ";?(block%+1)
PRINT "Entry   : ";~(?(block%+8)+256*?(block%+9))
PRINT "Block   :"
FOR I%=0 TO 15
PRINT ~I%;":";~?(block%+I%)
NEXT
PRINT
ENDPROC

