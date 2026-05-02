REM filename: opin01
REM
REM ----------------------------------------------------
REM BASIC OPENIN NETWORK RESOURCE
REM ----------------------------------------------------
REM requires "printf '\x00\x05OLLEH'" written to hello_print_hash.txt

CLS

X=OPENIN("http://192.168.1.101:18080/bbc/tests/hello_print_hash.txt")
IF X=0 PRINT "No file":END

INPUT#X, TXT$
PRINT TXT$

CLOSE# 0
