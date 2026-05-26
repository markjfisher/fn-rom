REM FujiNet long-string API helpers (OSWORD &78 / CALL)
REM CHAIN this file or COPY its PROCs/FNs into your program.
REM Note: BBC BASIC reserves FN… for functions — avoid names starting FN/fn.
REM DIM finBlock% … then finBlock%?n for bytes; finBlock% is the base address.

finOsword%=&78
finMosOsword%=&FFF1
finReasonVersion%=0
finReasonJsonQuery%=1
finReasonStashJson%=2
finReasonSetBodyLen%=3
finReasonWriteData%=4
finReasonSetContentProfile%=5
finStatusOk%=0
finStatusBadCall%=1
finStatusJsonQueryFailed%=2
finStatusBadChannel%=3
finProfileJson%=1
finProfileForm%=2
finProfileText%=3

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

DEF PROCfn_stash_json(path$)
PROCfnnet_init
PROCfnnet_set_str(path$)
PROCfnnet_rom_call(finReasonStashJson%)
ENDPROC

DEF PROCfnnet_set_body_len(n%)
finBlock%?0=finReasonSetBodyLen%
finBlock%?2=n% AND &FF
finBlock%?3=n% DIV 256
PROCfnnet_rom_call(finReasonSetBodyLen%)
ENDPROC

DEF PROCfnnet_set_content_profile(profile%)
finBlock%?0=finReasonSetContentProfile%
finBlock%?2=profile%
PROCfnnet_rom_call(finReasonSetContentProfile%)
ENDPROC

DEF PROCset_json_path(hndl%, path$)
LOCAL cmd$
finLastStatus%=finStatusOk%
IF LEN(path$)>60 THEN PROCfn_json_query(hndl%, path$) : ENDPROC
cmd$="FJSON "+STR$(hndl%)+" "+path$
OSCLI cmd$
ENDPROC
