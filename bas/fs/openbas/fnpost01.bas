REM filename: fnpost1
REM
REM ----------------------------------------------------
REM OSWORD &78 POST body smoke test
REM ----------------------------------------------------

finOsword%=&78
finMosOsword%=&FFF1
finReasonJsonQuery%=1
finReasonSetBodyLen%=4
finReasonWriteData%=5
finReasonSetContentProfile%=6
finProfileJson%=1

DIM finBuf% 512
DIM finBlock% 16
DIM readBuf% 256

CLS
PRINT "FujiNet POST body test"

body$="{""msg"":""bbc-post"",""mode"":""basic""}"
PRINT "Body length: ";LEN(body$)

PROCclear_block
PROCfnnet_set_body_len(LEN(body$))

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

PRINT "Set body len status: ";finBlock%?1

PROCfnnet_set_content_profile(finProfileJson%)

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

PRINT "Set content profile status: ";finBlock%?1

H%=OPENUP("http://192.168.1.101:8080/anything")
IF H%=0 PRINT "No file":END

PROCclear_block
PROCfnnet_set_str(body$)
finBlock%?0=finReasonWriteData%
finBlock%?6=H%

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

PRINT "Write data status: ";finBlock%?1

path$="/method"
PROCclear_block
PROCfnnet_set_str(path$)
finBlock%?0=finReasonJsonQuery%
finBlock%?6=H%

A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%

PRINT "Method query status: ";finBlock%?1
PROCread_sample(H%)

CLOSE#H%
END

DEF PROCfnnet_set_body_len(n%)
finBlock%?0=finReasonSetBodyLen%
finBlock%?4=n% AND &FF
finBlock%?5=n% DIV 256
ENDPROC

DEF PROCfnnet_set_content_profile(profile%)
finBlock%?0=finReasonSetContentProfile%
finBlock%?6=profile%
ENDPROC

DEF PROCfnnet_set_str(s$)
IF LEN(s$)>512 THEN ERROR 100,"String too long"
$(finBuf%)=s$+CHR$(0)
finBlock%?2=finBuf% AND &FF
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(s$) AND &FF
finBlock%?5=LEN(s$) DIV 256
ENDPROC

DEF PROCread_sample(h%)
LOCAL count%,result$
count%=0
result$=""
FOR I%=0 TO 255
  readBuf%?I%=0
NEXT

REPEAT
  IF EOF#h% THEN I%=255 ELSE readBuf%?count%=BGET#h%:result$=result$+CHR$(readBuf%?count%):count%=count%+1
UNTIL count%=16 OR I%=255

PRINT "count%: "; count%
PRINT "Method result: >";result$;"<"
PRINT "Len: ";LEN(result$)
PRINT "String bytes: ";
FOR I%=1 TO LEN(result$)
  PRINT FNhex2(ASC(MID$(result$,I%,1)));" ";
NEXT
PRINT
PRINT "Buffer: ";
FOR I%=0 TO count%
  PRINT FNhex2(readBuf%?I%);" ";
NEXT
PRINT

IF result$="POST" THEN PRINT "POST response received"

PRINT "String Len Check: "; LEN("POST")

ENDPROC

DEF PROCclear_block
FOR I%=0 TO 15
  ?(finBlock%+I%)=0
NEXT
ENDPROC

DEF FNhex2(v%)
=RIGHT$("0"+STR$~(v% AND 255),2)