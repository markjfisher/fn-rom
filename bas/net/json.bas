REM filename: json01
REM
REM ----------------------------------------------------
REM JSON Parsing example
REM ----------------------------------------------------
REM Uses httpbin service /get endpoint to fetch data

X=OPENIN("http://192.168.1.101:8080/get")
IF X=0 PRINT "No file":END

PRINT "    Accept: "; FNget_json(X, "/headers/Accept")
PRINT "      Host: "; FNget_json(X, "/headers/Host")
PRINT "User Agent: "; FNget_json(X, "/headers/User-Agent")
PRINT "    origin: "; FNget_json(X, "/origin")
PRINT "       url: "; FNget_json(X, "/url")
CLOSE# 0
END

DEF PROCset_json_path(hndl%, path$)
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
   ch%=BGET#hndl%
   e%=EOF#hndl%
   json$=json$+CHR$(ch%)
   idx%=idx%+1
  UNTIL e%=-1 OR idx%>=max_size%
=json$
