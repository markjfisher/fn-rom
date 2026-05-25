REM filename: o78bas
REM
REM ----------------------------------------------------
REM MINIMAL OSWORD &78 SERVICE 08 TEST
REM ----------------------------------------------------
REM Sends FujiNet reason 0 (version/bootstrap) directly via
REM MOS OSWORD, then prints the returned control block.

finOsword%=&78
finMosOsword%=&FFF1
finReasonVersion%=0

DIM finBlock% 16

CLS
PRINT "FujiNet OSWORD &78 test"
PRINT

REM Clear the whole block so stale values are obvious.
FOR I%=0 TO 15
finBlock%?I%=0
NEXT

finBlock%?0=finReasonVersion%

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

status%=finBlock%?1
entry%=finBlock%?8+256*finBlock%?9

PRINT "Reason  : ";finBlock%?0
PRINT "Status  : ";status%
PRINT "Entry   : ";~entry%
PRINT "Block   :"

FOR I%=0 TO 15
PRINT ~I%;":";~(finBlock%?I%)
NEXT
