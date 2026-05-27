REM filename: opin04
REM
REM ----------------------------------------------------
REM OPENIN via OSWORD &78 set-open-url + "://" sentinel
REM ----------------------------------------------------
REM BBC BASIC strings max 255 chars; URLs beyond that are
REM assembled in user RAM, armed with reason &04, then
REM opened with OPENIN("://").

finOsword%=&78
finMosOsword%=&FFF1
finReasonSetOpenUrl%=4
finOpenUrlSentinel$="://"
finStatusOk%=0

TARGET_LEN%=280

DIM finBuf% 512
DIM finBlock% 16

CLS
PRINT "Long URL buffer OPENIN test"

base$="http://192.168.1.101:18080/bbc/tests/simple.txt"
tail$="?"+STRING$(TARGET_LEN%-LEN(base$)-1,"a")
$(finBuf%)=base$+CHR$(0)
$(finBuf%+LEN(base$))=tail$
urlLen%=LEN(base$)+LEN(tail$)
PRINT "URL length: ";urlLen%

PROCfnnet_set_open_url(finBuf%, urlLen%)
IF finBlock%?1<>finStatusOk% THEN PRINT "Set open URL failed: ";finBlock%?1 : END

X=OPENIN(finOpenUrlSentinel$)
IF X=0 PRINT "No file":END

A=&FF
REPEAT
 B=EOF#X
 IF B<>-1 THEN A=BGET#X
 IF A<&80 PRINT CHR$(A);
UNTIL B=-1

CLOSE# 0
END

DEF PROCfnnet_set_open_url(addr%, len%)
IF len%>512 THEN ERROR 100,"String too long"
finBlock%?2=addr% AND &FF
finBlock%?3=addr% DIV 256
finBlock%?4=len% AND &FF
finBlock%?5=len% DIV 256
finBlock%?0=finReasonSetOpenUrl%
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%
ENDPROC
