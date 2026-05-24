REM filename: opin02
REM
REM ----------------------------------------------------
REM BASIC OPENIN NETWORK RESOURCE BGET
REM ----------------------------------------------------
REM
REM requires simple.txt with content "FujiNet OPENIN BGET Test" at given location

CLS

X=OPENIN("http://192.168.1.101:18080/bbc/tests/simple.txt")
IF X=0 PRINT "No file":END

A=&FF
REPEAT
 B=EOF#X
 IF B<>-1 THEN A=BGET#X
 IF A<&80 PRINT CHR$(A);
UNTIL B=-1

CLOSE# 0
