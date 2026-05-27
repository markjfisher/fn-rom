REM filename: fnjson0
REM
REM ----------------------------------------------------
REM JSON QUERY - missing path returns no data
REM ----------------------------------------------------

DIM readBuf% 64

path$="/no/such/path"

CLS
PRINT "FujiNet missing JSON path test"
PRINT

PROCrun_missing_path_test
END

DEF PROCrun_missing_path_test
LOCAL h%, t%
PRINT "*FJSON missing path"
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
FOR I%=0 TO 63
  readBuf%?I%=0
NEXT

REPEAT
  IF EOF#h% THEN I%=255 ELSE readBuf%?count%=BGET#h%:count%=count%+1
UNTIL count%=64 OR I%=255

PRINT "ReadLen   : ";count%
IF count%=0 THEN PRINT "Empty     : yes"
ENDPROC
