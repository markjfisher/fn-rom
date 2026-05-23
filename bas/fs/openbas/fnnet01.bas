REM filename: fnnet1
REM
REM ----------------------------------------------------
REM OSWORD &E0 long JSON path test (200+ byte selector)
REM ----------------------------------------------------
REM Requires httpbin on http://192.168.1.101:8080/get

FNNET_REASON_VERSION=0
FNNET_REASON_JSON_QUERY=1

DIM fnBuf 512
DIM fnBlock 16
fnCallEntry%=0

DEF PROCfnnet_init
IF fnCallEntry%=0 THEN PROCfnnet_query_version
ENDPROC

DEF PROCfnnet_query_version
fnBlock%?0=FNNET_REASON_VERSION
PROCfnnet_call(FNNET_REASON_VERSION)
IF fnBlock%?1=0 THEN fnCallEntry%=fnBlock%?8+256*fnBlock%?9
ENDPROC

DEF PROCfnnet_call(reason%)
LOCAL X%, Y%
IF fnCallEntry%=0 THEN PROCfnnet_query_version
IF fnCallEntry%=0 THEN ERROR 103,"FujiNet API unavailable"
X%=fnBlock%:Y%=X% DIV 256
A%=reason%
CALL fnCallEntry%
ENDPROC

DEF PROCfnnet_set_str(s$)
LOCAL l%
l%=LEN(s$)
IF l%>512 THEN ERROR 100,"String too long"
$(fnBuf)=s$+CHR$(0)
fnBlock%?2=fnBuf AND &FF
fnBlock%?3=fnBuf DIV 256
fnBlock%?4=l% AND &FF
fnBlock%?5=l% DIV 256
ENDPROC

DEF PROCfn_json_query(h%, path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
fnBlock%?6=h%
PROCfnnet_call(FNNET_REASON_JSON_QUERY)
IF fnBlock%?1<>0 THEN ERROR 101,"FJSON query failed"
ENDPROC

CLS
PRINT "FujiNet long JSON path test"

PROCfnnet_init
PRINT "FNNET API v";fnBlock%?1

X=OPENIN("http://192.168.1.101:8080/get")
IF X=0 PRINT "No file":END

path$="/url"
path$=path$+STRING$(200-LEN(path$),"x")
PRINT "Path length: ";LEN(path$)

PROCfn_json_query(X, path$)
PRINT "Long JSON path sent"
CLOSE# 0
