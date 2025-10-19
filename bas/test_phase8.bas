REM filename: 8OSFILE
REM Test OSFILE A=0 (save memory block) using inline assembly
DIM Code 50
DIM pBlock 20: REM Parameter block (18 bytes needed)
DIM fname 10
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!2=&1900: REM Load address
pBlock!6=&1900: REM Exec address
pBlock!10=&3000: REM Start address
pBlock!14=&3010: REM End address (16 bytes)
REM Put test data at &3000
?&3000=65:?&3001=66:?&3002=67:?&3003=68
REM Assemble OSFILE call
OSFILE=&FFDD
FOR I%=0 TO 2 STEP 2:P%=Code
  [OPT I%
   LDA #0
   LDX #pBlock MOD 256
   LDY #pBlock DIV 256
   JSR OSFILE
   RTS
  ]
NEXT I%
PRINT "Calling OSFILE A=0 to create TESTF1..."
R%=USR(Code)
PRINT "Return value: ";~R%
A%=R% AND &FF
PRINT "A register: ";A%
IF A%=1 THEN PRINT "SUCCESS: File created" ELSE PRINT "ERROR: A=";A%
*INFO TESTF1
