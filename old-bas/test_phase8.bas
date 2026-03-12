REM filename: 8OSFILE
REM Tesing OSFILE operations

DIM asmOSFILE 12
DIM pBlock 20: REM Parameter block (18 bytes needed)
DIM fname 10
DIM base_address 16: REM Test data block (dynamically allocated)
OSFILE=&FFDD

REM assemble the machine code
PROCasmInit

$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!2=&1900: REM Load address
pBlock!6=&1900: REM Exec address
pBlock!10=base_address: REM Start address (dynamic)
pBlock!14=base_address+16: REM End address (16 bytes)
$base_address="0123456789abcdef"

PRINT "Step 1: OSFILE(0) - create TESTF1"
A%=FNcallOSFILE(0)
IF A%=1 THEN PRINT "SUCCESS: File created" ELSE PRINT "ERROR: A=";A%:END
*INFO TESTF1

PRINT "Step 2: OSFILE(5) - Read catalog"
PROCreadCatalog
PRINT "Load=";~pBlock!2;" Exec=";~pBlock!6;" Length=";pBlock!10
IF pBlock!2<>&1900 THEN PRINT "ERROR: Load addr wrong, expected &1900":END
IF pBlock!6<>&1900 THEN PRINT "ERROR: Exec addr wrong, expected &1900":END
IF pBlock!10<>16 THEN PRINT "ERROR: Length wrong, expected 16":END
PRINT "SUCCESS: Catalog info correct"

REM Step 3: OSFILE A=1 - Update catalog (change load/exec)
PRINT "Step 3: OSFILE(1) - Update catalog"
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!2=&2000:REM New load address
pBlock!6=&2100:REM New exec address
A%=FNcallOSFILE(1)
IF A%=1 THEN PRINT "SUCCESS: Catalog updated" ELSE PRINT "ERROR: A=";A%:END
PRINT "Updated load=&2000, exec=&2100"

REM Step 4: Read back to verify
PRINT "Step 4: Verify update (A=5)"
PROCreadCatalog
IF pBlock!2<>&2000 THEN PRINT "ERROR: Load not updated":END
IF pBlock!6<>&2100 THEN PRINT "ERROR: Exec not updated":END
PRINT "SUCCESS: Load=";~pBlock!2;" Exec=";~pBlock!6

REM Step 5: OSFILE A=2 - Write load address only
PRINT "Step 5: OSFILE(2) - Write load addr only"
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!2=&3000:REM New load address
A%=FNcallOSFILE(2)
IF A%=1 THEN PRINT "SUCCESS: Load addr changed" ELSE PRINT "ERROR: A=";A%:END
PRINT "Changed load to &3000"

REM Verify step 5: Load changed, exec unchanged
PRINT "Verify: Read catalog after A=2"
PROCreadCatalog
IF pBlock!2<>&3000 THEN PRINT "ERROR: Load A=2 failed":END
IF pBlock!6<>&2100 THEN PRINT "ERROR: Exec changed (should stay &2100)":END
PRINT "SUCCESS: Load=";~pBlock!2;" Exec=";~pBlock!6;" (unchanged)"

REM Step 6: OSFILE A=3 - Write exec address only
PRINT "Step 6: OSFILE(3) - Write exec addr only"
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock!6=&3100:REM New exec address
A%=FNcallOSFILE(3)
IF A%=1 THEN PRINT "SUCCESS: Exec addr changed" ELSE PRINT "ERROR: A=";A%:END
PRINT "Changed exec to &3100"

REM Verify step 6: Load unchanged, exec changed
PRINT "Verify: Read catalog after A=3"
PROCreadCatalog
IF pBlock!2<>&3000 THEN PRINT "ERROR: Load changed (should stay &3000)":END
IF pBlock!6<>&3100 THEN PRINT "ERROR: Exec A=3 failed":END
PRINT "SUCCESS: Load=";~pBlock!2;" (unchanged) Exec=";~pBlock!6

REM Step 7: Final verification with *INFO
PRINT "Step 7: Final check with *INFO"
*INFO TESTF1
PRINT "Should show: $.TESTF1 L 003000 003100"

REM Step 8: OSFILE A=4 - Lock file
PRINT "Step 8: OSFILE(4) - Lock file"
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock?14=8:REM Set locked bit (bit 3)
A%=FNcallOSFILE(4)
IF A%=1 THEN PRINT "SUCCESS: File locked" ELSE PRINT "ERROR: A=";A%:END

REM Verify step 8: File is locked
PRINT "Verify: Check locked status"
PROCreadCatalog
IF pBlock?14<>8 THEN PRINT "ERROR: File not locked, attr=";pBlock?14:END
PRINT "SUCCESS: File locked (attr=";pBlock?14;")"
*INFO TESTF1
PRINT "Should show 'L' flag"

REM Step 9: Try to delete locked file (should fail)
PRINT "Step 9: Try delete locked file"
ON ERROR PRINT "SUCCESS: Cannot delete locked": GOTO 500
*DELETE TESTF1
PRINT "ERROR: Deleted locked file!":END
500 REM success case

REM Step 10: Unlock file
PRINT "Step 10: OSFILE(4) - Unlock file"
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
pBlock?14=0:REM Clear locked bit
A%=FNcallOSFILE(4)
IF A%=1 THEN PRINT "SUCCESS: File unlocked" ELSE PRINT "ERROR: A=";A%:END

REM Verify step 10: File is unlocked
PRINT "Verify: Check unlocked status"
PROCreadCatalog
IF pBlock?14<>0 THEN PRINT "ERROR: File still locked, attr=";pBlock?14:END
PRINT "SUCCESS: File unlocked (attr=";pBlock?14;")"
*INFO TESTF1
PRINT "Should NOT show 'L' flag"

REM Step 11: Now delete should work
PRINT "Step 11: Delete unlocked file"
*DELETE TESTF1
PRINT "SUCCESS: File deleted"
H%=OPENIN("TESTF1")
IF H%<>0 THEN PRINT "ERROR: File still exists":CLOSE#H%:END
PRINT "Confirmed: File deleted"

PRINT:PRINT "*** ALL OSFILE TESTS PASSED ***"
*INFO *

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

DEF PROCreadCatalog
REM Clear parameter block to ensure fresh data
pBlock!2=0:pBlock!6=0:pBlock!10=0:pBlock!14=0
$fname="TESTF1"+CHR$(13)
pBlock!0=fname
A%=FNcallOSFILE(5)
IF A%=0 THEN PRINT "ERROR: File not found":END
ENDPROC
