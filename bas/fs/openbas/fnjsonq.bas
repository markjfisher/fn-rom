REM filename: fnjsonq
REM
REM ----------------------------------------------------
REM JSON QUERY - FJSON version
REM ----------------------------------------------------

DIM readBuf% 128

path$="/url"

CLS
PRINT "FujiNet FJSON test"
PRINT

PROCrun_fjson_test
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

DEF PROCread_sample(h%)
LOCAL count%
count%=0
FOR I%=0 TO 127
readBuf%?I%=0
NEXT

REPEAT
IF EOF#h% THEN I%=255 ELSE readBuf%?count%=BGET#h%:count%=count%+1
UNTIL count%=64 OR I%=255

PRINT "ReadLen   : ";count%
PRINT "ReadHex   : "
PROCprint_hex_bytes(readBuf%,count%)
PROCprint_string(readBuf%,count%)

ENDPROC

DEF PROCprint_hex_bytes(addr%,count%)
FOR I%=0 TO count%-1
  PRINT FNhex2(?(addr%+I%));" ";
  IF (I%+1) MOD 8 = 0 THEN PRINT
NEXT
PRINT
ENDPROC

DEF PROCprint_string(addr%,count%)
PRINT "String : ";
FOR I%=0 TO count%-1
  PRINT CHR$(?(addr%+I%));
NEXT
PRINT
ENDPROC

DEF FNhex2(v%)
=RIGHT$("0"+STR$~(v% AND 255),2)
