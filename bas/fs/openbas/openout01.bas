REM filename: opout01
REM
REM ----------------------------------------------------
REM BASIC OPENOUT NETWORK RESOURCE
REM write and read from echo service
REM ----------------------------------------------------

CLS

*OPT 6,1
X=OPENOUT("tcp://192.168.1.101:7777")

REM write 3 bytes
BPUT#X,65
BPUT#X,66
BPUT#X,67

REM read them back and print them
A=BGET#X
B=BGET#X
C=BGET#X
D=BGET#X
REM prove we are at the end
E=EOF#X

PRINT CHR$(A);CHR$(B);CHR$(C);E

CLOSE# 0
