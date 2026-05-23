REM filename: opin03
REM
REM ----------------------------------------------------
REM BASIC OPENIN with long URL (300+ bytes)
REM ----------------------------------------------------
REM Requires simple.txt at the path below (same as opin02).

CLS
PRINT "Long URL OPENIN test"

base$="http://192.168.1.101:18080/bbc/tests/simple.txt"
pad$=STRING$(300-LEN(base$)-1,"a")
url$=base$+"?"+pad$
PRINT "URL length: ";LEN(url$)

X=OPENIN(url$)
IF X=0 PRINT "No file":END

REPEAT
 A=BGET#X
 IF A<&80 PRINT CHR$(A);
 B=EOF#X
UNTIL B

CLOSE# 0
