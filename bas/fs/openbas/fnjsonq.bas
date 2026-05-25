REM filename: fnjsonq
REM
REM ----------------------------------------------------
REM JSON QUERY COMPARISON TEST
REM ----------------------------------------------------
REM Compares *FJSON against OSWORD &78 reason 1 using the same
REM URL and JSON selector on separate OPENIN handles.

finOsword%=&78
finMosOsword%=&FFF1
finReasonJsonQuery%=1

DIM finBlock% 16
DIM finBuf% 32
DIM readBuf% 128

path$="/url"

CLS
PRINT "FujiNet JSON query comparison"
PRINT

PROCrun_fjson_test
PRINT
PROCrun_osword_test
END

DEF PROCrun_fjson_test
LOCAL h%, t%
PRINT "*FJSON test"
t%=TIME
h%=OPENIN("http://192.168.1.101:8080/get")
IF h%=0 PRINT "No file":ENDPROC
PRINT "OpenTicks : ";TIME-t%
PRINT "Handle    : ";h%

t%=TIME
OSCLI "FJSON "+STR$(h%)+" "+path$
PRINT "JsonTicks : ";TIME-t%

PROCread_sample(h%)
CLOSE#h%
ENDPROC

DEF PROCrun_osword_test
LOCAL h%, t%
PRINT "OSWORD &78 test"
t%=TIME
h%=OPENIN("http://192.168.1.101:8080/get")
IF h%=0 PRINT "No file":ENDPROC
PRINT "OpenTicks : ";TIME-t%
PRINT "Handle    : ";h%

$(finBuf%)=path$+CHR$(0)
PROCclear_block
finBlock%?0=finReasonJsonQuery%
finBlock%?2=finBuf% MOD 256
finBlock%?3=finBuf% DIV 256
finBlock%?4=LEN(path$) MOD 256
finBlock%?5=LEN(path$) DIV 256
finBlock%?6=h%

PRINT "Path      : ";path$
PRINT "Block     : ";~finBlock%
PRINT "Buffer    : ";~finBuf%

t%=TIME
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%
PRINT "JsonTicks : ";TIME-t%

PRINT "Reason    : ";finBlock%?0;TAB(20);"Status : ";finBlock%?1
PRINT "Handle    : ";finBlock%?6;TAB(20);"Len    : ";finBlock%?4+256*finBlock%?5
PRINT "Ptr       : ";~(finBlock%?2+256*finBlock%?3)
PRINT "BlockHex  : ";
PROCprint_hex_bytes(finBlock%,16)

PROCread_sample(h%)
CLOSE#h%
ENDPROC

DEF PROCread_sample(h%)
LOCAL count%
count%=0
FOR I%=0 TO 127
readBuf%?I%=0
NEXT

REPEAT
IF EOF#h% THEN I%=127 ELSE readBuf%?count%=BGET#h%:count%=count%+1
UNTIL count%=64 OR I%=127

PRINT "ReadLen   : ";count%
PRINT "ReadHex   : ";
PROCprint_hex_bytes(readBuf%,count%)
ENDPROC

DEF PROCclear_block
FOR I%=0 TO 15
?(finBlock%+I%)=0
NEXT
ENDPROC

DEF PROCprint_hex_bytes(addr%,count%)
FOR I%=0 TO count%-1
PRINT FNhex2(?(addr%+I%));" ";
NEXT
PRINT
ENDPROC

DEF FNhex2(v%)
=RIGHT$("0"+STR$~(v% AND 255),2)
