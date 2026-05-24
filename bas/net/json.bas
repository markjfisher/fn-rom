REM filename: json01
REM
REM ----------------------------------------------------
REM JSON Parsing example
REM ----------------------------------------------------
REM Uses httpbin service /get endpoint to fetch data

X=OPENIN("http://192.168.1.101:8080/get")
IF X=0 PRINT "No file":END

CLS
PRINT "Performing JSON"
PRINT "queries against httpbin /get"
PRINT
PRINT "   Accept: "; FNget_json(X, "/headers/Accept")
PRINT "     Host: "; FNget_json(X, "/headers/Host")
PRINT "UserAgent: "; FNget_json(X, "/headers/User-Agent")
PRINT "   origin: "; FNget_json(X, "/origin")
PRINT "      url: "; FNget_json(X, "/url")
CLOSE# 0
END

finOsword%=&78
finMosOsword%=&FFF1
finReasonVersion%=0
finReasonJsonQuery%=1

DEF PROCset_json_path(hndl%, path$)
IF LEN(path$)>60 THEN PROCfn_json_query(hndl%, path$) : ENDPROC
cmd$="FJSON "+STR$(hndl%)+" "+path$
OSCLI cmd$
ENDPROC

DEF FNget_json(hndl%, path$)
  LOCAL max_size%, idx%, ch%, e%
  max_size%=200
  idx%=0
  PROCset_json_path(hndl%, path$)
  json$=STRING$(200," ")
  json$=""
  REPEAT
   e%=EOF#hndl%
   IF e%<>-1 THEN ch%=BGET#hndl% : json$=json$+CHR$(ch%) : idx%=idx%+1
  UNTIL e%=-1 OR idx%>=max_size%
=json$

REM --- fnnet library (bas/lib/fnnet.bas) ---
DIM finBuf% 512
DIM finBlock% 16
finCallEntry%=0

DEF PROCfnnet_init
IF finCallEntry%=0 THEN PROCfnnet_query_version
ENDPROC

DEF PROCfnnet_query_version
finBlock%?0=finReasonVersion%
IF finCallEntry%=0 THEN PROCfnnet_osword ELSE PROCfnnet_rom_call(finReasonVersion%)
IF finBlock%?1=0 THEN finCallEntry%=finBlock%?8+256*finBlock%?9
ENDPROC

DEF PROCfnnet_osword
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
=USRfinMosOsword%
ENDPROC

DEF PROCfnnet_rom_call(reason%)
IF finCallEntry%=0 THEN ERROR 103,"FujiNet API unavailable"
A%=reason%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
=USRfinCallEntry%
ENDPROC

DEF PROCfnnet_set_str(s$)
IF LEN(s$)>512 THEN ERROR 100,"String too long"
$(finBuf%)=s$+CHR$(0)
finBlock%?2=finBuf% AND &FF
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(s$) AND &FF
finBlock%?5=LEN(s$) DIV 256
ENDPROC

DEF PROCfn_json_query(h%, path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
finBlock%?6=h%
PROCfnnet_rom_call(finReasonJsonQuery%)
ENDPROC
