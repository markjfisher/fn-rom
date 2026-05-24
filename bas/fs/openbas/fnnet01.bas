REM filename: fnnet1
REM
REM ----------------------------------------------------
REM OSWORD &78 long JSON path test (200-byte selector)
REM ----------------------------------------------------
REM Opens httpbin /get, then scatter-sends a 200-byte JSON
REM selector via TranslateConfigure (reason finReasonJsonQuery%).
REM Requires http://192.168.1.101:8080/get

finOsword%=&78
finMosOsword%=&FFF1
finReasonVersion%=0
finReasonJsonQuery%=1
finApiVersion%=1
finStatusOk%=0
finStatusBadCall%=1
finStatusJsonQueryFailed%=2
finStatusBadChannel%=3

DIM finBuf% 512
DIM finBlock% 16
finCallEntry%=0
finLastStatus%=finStatusOk%

DEF PROCfnnet_init
IF finCallEntry%=0 THEN PROCfnnet_query_version
ENDPROC

DEF PROCfnnet_query_version
finBlock%?0=finReasonVersion%
IF finCallEntry%=0 THEN PROCfnnet_osword ELSE PROCfnnet_rom_call(finReasonVersion%)
finLastStatus%=finBlock%?1
IF finBlock%?1=0 THEN finCallEntry%=finBlock%?8+256*finBlock%?9
ENDPROC

REM Bootstrap via OSWORD &78 before ROM entry address is known.
DEF PROCfnnet_osword
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%
ENDPROC


DEF PROCfnnet_rom_call(reason%)
IF finCallEntry%=0 THEN ERROR 103,"FujiNet API unavailable"
A%=reason%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finCallEntry%
finLastStatus%=finBlock%?1
ENDPROC

DEF PROCfnnet_set_str(s$)
IF LEN(s$)>512 THEN ERROR 100,"String too long"
$(finBuf%)=s$+CHR$(0)
finBlock%?2=finBuf% AND &FF
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(s$) AND &FF
finBlock%?5=LEN(s$) DIV 256
ENDPROC

DEF PROCfnnet_set_str_ptr(addr%, len%)
IF len%>512 THEN ERROR 100,"String too long"
finBlock%?2=addr% AND &FF
finBlock%?3=addr% DIV 256
finBlock%?4=len% AND &FF
finBlock%?5=len% DIV 256
ENDPROC

DEF PROCfn_json_query(h%, path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
finBlock%?6=h%
PROCfnnet_rom_call(finReasonJsonQuery%)
ENDPROC

CLS
PRINT "FujiNet long JSON path test"

PROCfnnet_init
PRINT "FujiNet API v";finApiVersion%

X=OPENIN("http://192.168.1.101:8080/get")
IF X=0 PRINT "No file":END

path$="/url"
path$=path$+STRING$(200-LEN(path$),"x")
PRINT "Path length: ";LEN(path$)

PROCfn_json_query(X, path$)
PRINT "Long JSON path status: ";finLastStatus%
CLOSE# 0
