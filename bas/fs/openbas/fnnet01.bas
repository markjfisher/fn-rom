REM filename: fnnet1
REM
REM ----------------------------------------------------
REM ----------------------------------------------------
REM OSWORD &78 long JSON path test (200-byte selector)
REM ----------------------------------------------------
REM Opens httpbin /get, then sends a 200-byte JSON selector via
REM OSWORD &78 reason 0.

finOsword%=&78
finMosOsword%=&FFF1
finReasonJsonQuery%=0
finStatusOk%=0

DIM finBuf% 512
DIM finBlock% 16
DIM readBuf% 256

CLS
PRINT "FujiNet long JSON path test"

X=OPENIN("http://192.168.1.101:8080/get")
IF X=0 PRINT "No file":END

path$="/url"
path$=path$+STRING$(200-LEN(path$),"x")
PRINT "Path length: ";LEN(path$)

PROCclear_block
PROCfnnet_set_str(path$)
finBlock%?0=finReasonJsonQuery%
finBlock%?6=X

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

finLastStatus%=finBlock%?1
PRINT "Long JSON path status: ";finLastStatus%

PROCread_sample(X)

CLOSE#X
END

DEF PROCfnnet_set_str(s$)
IF LEN(s$)>512 THEN ERROR 100,"String too long"
$(finBuf%)=s$+CHR$(0)
finBlock%?2=finBuf% AND &FF
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(s$) AND &FF
finBlock%?5=LEN(s$) DIV 256
ENDPROC

DEF PROCread_sample(h%)
LOCAL count%
count%=0
FOR I%=0 TO 255
readBuf%?I%=0
NEXT

REPEAT
IF EOF#h% THEN I%=255 ELSE readBuf%?count%=BGET#h%:count%=count%+1
UNTIL count%=64 OR I%=255

PRINT "ReadLen : ";count%
IF count%>0 PRINT "Long JSON path sent"
ENDPROC

DEF PROCclear_block
FOR I%=0 TO 15
?(finBlock%+I%)=0
NEXT
ENDPROC
