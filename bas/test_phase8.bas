REM filename: 8OSFILE
REM Tesing OSFILE operations

DIM asmOSFILE 12
DIM pBlock 20: REM Parameter block (18 bytes needed)
DIM fname 10
OSFILE=&FFDD

REM assemble the machine code
PROCasmInit

$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!2=&1900: REM Load address
pBlock!6=&1900: REM Exec address
pBlock!10=&3000: REM Start address
pBlock!14=&3010: REM End address (16 bytes)
?&3000=65:?&3001=66:?&3002=67:?&3003=68

PRINT "Step 1: OSFILE(0) - create TESTF1"
A%=FNcallOSFILE(0)
IF A%=1 THEN PRINT "SUCCESS: File created" ELSE PRINT "ERROR: A=";A%:END
*INFO TESTF1

PRINT "Step 2: OSFILE(5) - Read catalog"
REM Clear param block first to verify it gets updated
pBlock!2=0:pBlock!6=0:pBlock!10=0:pBlock!14=0
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
A%=FNcallOSFILE(5)
IF A%=0 THEN PRINT "ERROR: File not found":END
PRINT "A=";A%;" (1=found)"
PRINT "Load=";~pBlock!2
PRINT "Exec=";~pBlock!6
PRINT "Length=";pBlock!10;" (&";~pBlock!10;")"
IF pBlock!2<>&1900 THEN PRINT "ERROR: Load addr wrong, expected &1900":END
IF pBlock!6<>&1900 THEN PRINT "ERROR: Exec addr wrong, expected &1900":END
IF pBlock!10<>16 THEN PRINT "ERROR: Length wrong, expected 16":END
PRINT "SUCCESS: Catalog info correct"

INPUT "Press any key to continue", dummy$

END

REM ONLY PUT PROC AND FN DEFINITIONS PAST THIS LINE

DEF PROCasmInit
FOR I%=0 TO 2 STEP 2:P%=asmOSFILE
  [OPT I%
   LDA &70
   LDX #pBlock MOD 256
   LDY #pBlock DIV 256
   JSR OSFILE
   RTS
  ]
NEXT I%
ENDPROC

DEF FNcallOSFILE(a)
?&70=a
R%=USR(asmOSFILE)
=(R% AND &FF)
