REM filename: opin03
REM
REM ----------------------------------------------------
REM BASIC OPENIN with long URL (BBC string, up to 255 chars)
REM ----------------------------------------------------
REM Requires simple.txt at the path below (same as opin02).
REM Query padding exercises ROM scatter path (>64-byte old limit).
REM BBC BASIC string variables max 255 chars; URLs beyond that need
REM a buffer approach (see bas/lib/fnnet.bas / docs/fnnet-api.md).

TARGET_LEN%=240

CLS
PRINT "Long URL OPENIN test"

base$="http://192.168.1.101:18080/bbc/tests/simple.txt"
pad$=STRING$(TARGET_LEN%-LEN(base$)-1,"a")
url$=base$+"?"+pad$
PRINT "URL length: ";LEN(url$)

X=OPENIN(url$)
IF X=0 PRINT "No file":END

A=&FF
REPEAT
 B=EOF#X
 IF B<>-1 THEN A=BGET#X
 IF A<&80 PRINT CHR$(A);
UNTIL B=-1

CLOSE# 0
