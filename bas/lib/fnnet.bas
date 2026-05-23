REM FujiNet long-string API helpers (OSWORD &E0 / CALL)
REM CHAIN this file or COPY its PROCs/FNs into your program.

FNNET_OSWORD=&E0
FNNET_REASON_VERSION=0
FNNET_REASON_JSON_QUERY=1
FNNET_REASON_STASH_JSON=2

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

DEF PROCfnnet_set_str_ptr(addr%, len%)
IF len%>512 THEN ERROR 100,"String too long"
fnBlock%?2=addr% AND &FF
fnBlock%?3=addr% DIV 256
fnBlock%?4=len% AND &FF
fnBlock%?5=len% DIV 256
ENDPROC

DEF PROCfn_json_query(h%, path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
fnBlock%?6=h%
PROCfnnet_call(FNNET_REASON_JSON_QUERY)
IF fnBlock%?1<>0 THEN ERROR 101,"FJSON query failed"
ENDPROC

DEF PROCfn_stash_json(path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
PROCfnnet_call(FNNET_REASON_STASH_JSON)
IF fnBlock%?1<>0 THEN ERROR 102,"FJSON stash failed"
ENDPROC

DEF PROCset_json_path(hndl%, path$)
IF LEN(path$)>60 THEN PROCfn_json_query(hndl%, path$) : ENDPROC
cmd$="FJSON "+STR$(hndl%)+" "+path$
OSCLI cmd$
ENDPROC
