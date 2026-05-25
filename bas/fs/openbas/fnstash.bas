REM filename: o78stsh
REM
REM ----------------------------------------------------
REM OSWORD &78 STASH JSON PATH TEST
REM ----------------------------------------------------
REM Sends reason 2 with a short fixed string via OSWORD &78.
REM This tests service 08 plus fnnet_load_ext_str without OPENIN.

finOsword%=&78
finMosOsword%=&FFF1
finReasonStashJson%=2

DIM finBlock% 16
DIM finBuf% 32

CLS
PRINT "FujiNet OSWORD stash test"
PRINT

path$="/url"
$(finBuf%)=path$+CHR$(0)

FOR I%=0 TO 15
?(finBlock%+I%)=0
NEXT

finBlock%?0=finReasonStashJson%
finBlock%?2=finBuf% MOD 256
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(path$) MOD 256
finBlock%?5=LEN(path$) DIV 256

PRINT "Path    : ";path$
PRINT "Block   : ";~finBlock%
PRINT "Buffer  : ";~finBuf%

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

PRINT "Reason  : ";finBlock%?0; "     Status : ";finBlock%?1; "     Len : ";finBlock%?4+256*finBlock%?5
PRINT "Ptr     : ";~(finBlock%?2+256*finBlock%?3)
PRINT "Block   :"

FOR I%=0 TO 15
PRINT ~I%;":";~?(finBlock%+I%)
NEXT
