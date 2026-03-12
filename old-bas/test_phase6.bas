   10 REM filename: 6DELETE
   20 REM Phase 6: File Deletion Test
   30 REM Tests:
   40 REM - Create test files
   50 REM - Delete files using *DELETE command
   60 REM - Verify files are gone from catalog
   70 :
   80 PRINT "Phase 6: File Deletion Test"
   90 PRINT "============================"
  100 :
  110 REM --- STEP 1: Create test files ---
  120 PRINT "Step 1: Creating TEST1 with 'AAA'"
  130 H%=OPENOUT("TEST1")
  140 BPUT#H%,65:BPUT#H%,65:BPUT#H%,65
  150 CLOSE#H%
  160 :
  170 PRINT "Step 2: Creating TEST2 with 'BBB'"
  180 H%=OPENOUT("TEST2")
  190 BPUT#H%,66:BPUT#H%,66:BPUT#H%,66
  200 CLOSE#H%
  210 :
  220 PRINT "Step 3: Creating TEST3 with 'CCC'"
  230 H%=OPENOUT("TEST3")
  240 BPUT#H%,67:BPUT#H%,67:BPUT#H%,67
  250 CLOSE#H%
  260 :
  270 REM --- STEP 4: Verify files exist ---
  280 PRINT "Step 4: Verify files exist with *CAT"
  290 *CAT
  300 PRINT
  310 :
  320 REM --- STEP 5: Delete TEST1 using *DELETE ---
  330 PRINT "Step 5: Deleting TEST1 using *DELETE"
  340 *DELETE TEST1
  350 PRINT "TEST1 deleted"
  360 :
  370 REM --- STEP 6: Verify TEST1 is gone ---
  380 PRINT "Step 6: Verify TEST1 is gone"
  390 *CAT
  400 PRINT
  410 :
  420 REM --- STEP 7: Delete TEST2 using *DELETE ---
  430 PRINT "Step 7: Deleting TEST2 using *DELETE"
  440 *DELETE TEST2
  450 PRINT "TEST2 deleted"
  460 :
  470 REM --- STEP 8: Verify TEST2 is gone ---
  480 PRINT "Step 8: Verify TEST2 is gone"
  490 *CAT
  500 PRINT
  510 :
  520 REM --- STEP 9: Try to read deleted files ---
  530 PRINT "Step 9: Try to read TEST1 (should fail)"
  540 H%=OPENIN("TEST1")
  550 IF H%<>0 THEN PRINT "ERROR: TEST1 still exists!" : END
  560 PRINT "Good: TEST1 not found (H%=0)"
  570 :
  580 PRINT "Step 10: Try to read TEST2 (should fail)"
  590 H%=OPENIN("TEST2")
  600 IF H%<>0 THEN PRINT "ERROR: TEST2 still exists!" : END
  610 PRINT "Good: TEST2 not found (H%=0)"
  660 :
  670 REM --- STEP 11: Verify TEST3 still exists ---
  680 PRINT "Step 11: Verify TEST3 still exists"
  690 H%=OPENIN("TEST3")
  700 C$=""
  710 FOR I%=1 TO 3
  720   C$=C$+CHR$(BGET#H%)
  730 NEXT
  740 CLOSE#H%
  750 PRINT "TEST3 content: '";C$;"'"
  760 IF C$="CCC" THEN PRINT "TEST3 OK" ELSE PRINT "TEST3 CORRUPTED!"
  770 :
  780 REM --- STEP 12: Clean up TEST3 ---
  790 PRINT "Step 12: Delete TEST3"
  800 *DELETE TEST3
  810 :
  820 REM --- FINAL SUMMARY ---
  830 PRINT
  840 PRINT "============================"
  850 PRINT "Phase 6 Complete!"
  860 IF C$="CCC" THEN PRINT "ALL TESTS PASSED" ELSE PRINT "SOME TESTS FAILED"
  870 PRINT "============================"
  880 END
