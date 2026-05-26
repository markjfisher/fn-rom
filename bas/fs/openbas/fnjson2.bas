REM filename: fnjson2
REM
REM ----------------------------------------------------
REM Multi JSON query on one handle (OSWORD &78)
REM ----------------------------------------------------
REM Like iss.bas lat/lon: OPENIN once, then reason 0
REM (TranslateConfigure) before each BGET# field read.

finOsword%=&78
finMosOsword%=&FFF1
finReasonJsonQuery%=0

DIM finBlock% 16
DIM finBuf% 64
DIM readBuf% 128

url$="http://192.168.1.101:8080/get"

CLS
PRINT "FujiNet multi JSON query test"
PRINT

PROCrun_multi_query_test
END

DEF PROCrun_multi_query_test
LOCAL h%, t%
PRINT "Two fields from one /get handle"
PRINT

t%=TIME
h%=OPENIN(url$)
IF h%=0 PRINT "No file":ENDPROC
PRINT "OpenTicks : ";TIME-t%
PRINT "Handle    : ";h%
PRINT

PROCquery_field(h%, "/url", "url")
PROCquery_field(h%, "/headers/Host", "headers/Host")

CLOSE#h%
ENDPROC

DEF PROCquery_field(h%, path$, label$)
PROCfnnet_set_str(path$)
finBlock%?0=finReasonJsonQuery%
finBlock%?6=h%
PROCfnnet_osword
PRINT label$;" query stat: ";finBlock%?1
IF finBlock%?1=0 THEN PROCread_field(h%, label$)
PRINT
ENDPROC

DEF PROCfnnet_osword
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%
ENDPROC

DEF PROCfnnet_set_str(s$)
$(finBuf%)=s$+CHR$(0)
finBlock%?2=finBuf% MOD 256
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(s$) MOD 256
finBlock%?5=LEN(s$) DIV 256
ENDPROC

DEF PROCread_field(h%, label$)
LOCAL count%
count%=0
FOR I%=0 TO 127
readBuf%?I%=0
NEXT

REPEAT
IF EOF#h% THEN I%=127 ELSE readBuf%?count%=BGET#h%:count%=count%+1
UNTIL count%=64 OR I%=127

PRINT label$;" Len: ";count%
IF count%>0 THEN PROCprint_string(readBuf%,count%)
ENDPROC

DEF PROCprint_string(addr%,count%)
PRINT "  String : ";
FOR I%=0 TO count%-1
  PRINT CHR$(?(addr%+I%));
NEXT
PRINT
ENDPROC
