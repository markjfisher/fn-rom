REM filename: open
REM test openin with reading a file

?(&70)=0

REM data has "ABC" characters
X=OPENIN("DATA")

dA=BGET#X
?(&71)=0
dB=BGET#X
dC=BGET#X
PRINT dA;" "; dB;" ";dC

isEOF=EOF#X
PRINT isEOF
CLOSE#X
