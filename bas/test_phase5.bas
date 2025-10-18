   10 REM filename: 5RAND
   15 REM Phase 5: Random Access Write Test
   20 REM Tests:
   30 REM - Create 2 files with initial data
   40 REM - Close both
   50 REM - Reopen for random access (OPENUP)
   60 REM - Overwrite byte at position 1
   70 REM - Append 1 byte to end of each file
   80 REM - Close both
   90 REM - Reopen and verify size and content
  100 REM - Close both
  110 :
  120 PRINT "Phase 5: Random Access Write Test"
  130 PRINT "==================================="
  140 :
  150 REM --- STEP 1: Create FILE1 with "ABC" ---
  160 PRINT "Step 1: Creating FILE1 with 'ABC'"
  170 H1%=OPENOUT("FILE1")
  180 BPUT#H1%,65  : REM 'A'
  190 BPUT#H1%,66  : REM 'B'
  200 BPUT#H1%,67  : REM 'C'
  210 PRINT "FILE1 created (3 bytes)"
  220 :
  230 REM --- STEP 2: Create FILE2 with "XYZ" ---
  240 PRINT "Step 2: Creating FILE2 with 'XYZ'"
  250 H2%=OPENOUT("FILE2")
  260 BPUT#H2%,88  : REM 'X'
  270 BPUT#H2%,89  : REM 'Y'
  280 BPUT#H2%,90  : REM 'Z'
  290 PRINT "FILE2 created (3 bytes)"
  300 :
  310 REM --- STEP 3: Close both files ---
  320 PRINT "Step 3: Closing both files"
  330 CLOSE#H1%
  340 CLOSE#H2%
  350 PRINT "Both files closed"
  360 :
  370 REM --- STEP 4: Verify initial state with *INFO ---
  380 PRINT "Step 4: Initial file info:"
  390 *INFO FILE1
  400 *INFO FILE2
  410 :
  420 REM --- STEP 5: Reopen for random access (OPENUP) ---
  430 PRINT "Step 5: Reopening for random access"
  440 H1%=OPENUP("FILE1")
  450 H2%=OPENUP("FILE2")
  460 PRINT "Both files opened for update"
  470 :
  480 REM --- STEP 6: Overwrite byte 1 in FILE1 ---
  490 PRINT "Step 6: Overwrite FILE1 byte 1: 'B' -> 'Q'"
  500 REM PTR#H1%=0 : REM Seek to start (implicit after OPENUP)
  510 B%=BGET#H1%   : REM Read 'A' (advances PTR to 1)
  520 REM Now PTR#H1%=1, overwrite 'B' with 'Q'
  530 BPUT#H1%,81   : REM 'Q'
  540 :
  550 REM --- STEP 7: Overwrite byte 1 in FILE2 ---
  560 PRINT "Step 7: Overwrite FILE2 byte 1: 'Y' -> 'P'"
  570 B%=BGET#H2%   : REM Read 'X' (advances PTR to 1)
  580 BPUT#H2%,80   : REM 'P'
  590 :
  600 REM --- STEP 8: Seek to end of FILE1 and append '!' ---
  610 PRINT "Step 8: Append '!' to FILE1 (byte 3)"
  620 PTR#H1%=3     : REM Seek to end (after 'C')
  630 BPUT#H1%,33   : REM '!'
  640 PRINT "FILE1 now 4 bytes: 'AQC!'"
  650 :
  660 REM --- STEP 9: Seek to end of FILE2 and append '@' ---
  670 PRINT "Step 9: Append '@' to FILE2 (byte 3)"
  680 PTR#H2%=3     : REM Seek to end (after 'Z')
  690 BPUT#H2%,64   : REM '@'
  700 PRINT "FILE2 now 4 bytes: 'XPZ@'"
  710 :
  720 REM --- STEP 10: Close both files ---
  730 PRINT "Step 10: Closing both files"
  740 CLOSE#H1%
  750 CLOSE#H2%
  760 PRINT "Both files closed"
  770 :
  780 REM --- STEP 11: Verify final state with *INFO ---
  790 PRINT "Step 11: Final file info (should be 4 bytes):"
  800 *INFO FILE1
  810 *INFO FILE2
  820 :
  830 REM --- STEP 12: Read back FILE1 and verify ---
  840 PRINT "Step 12: Reading FILE1 (expect 'AQC!')"
  850 H1%=OPENIN("FILE1")
  860 S1$=""
  870 FOR I%=1 TO 4
  880   B%=BGET#H1%
  890   S1$=S1$+CHR$(B%)
  900 NEXT I%
  910 PRINT "FILE1 content: '";S1$;"'"
  920 IF S1$="AQC!" THEN PRINT "FILE1 PASS" ELSE PRINT "FILE1 FAIL!"
  930 :
  940 REM --- STEP 13: Read back FILE2 and verify ---
  950 PRINT "Step 13: Reading FILE2 (expect 'XPZ@')"
  960 H2%=OPENIN("FILE2")
  970 S2$=""
  980 FOR I%=1 TO 4
  990   B%=BGET#H2%
 1000   S2$=S2$+CHR$(B%)
 1010 NEXT I%
 1020 PRINT "FILE2 content: '";S2$;"'"
 1030 IF S2$="XPZ@" THEN PRINT "FILE2 PASS" ELSE PRINT "FILE2 FAIL!"
 1040 :
 1050 REM --- STEP 14: Close both files ---
 1060 PRINT "Step 14: Closing both files"
 1070 CLOSE#H1%
 1080 CLOSE#H2%
 1090 :
 1100 REM --- FINAL SUMMARY ---
 1110 PRINT
 1120 PRINT "==================================="
 1130 PRINT "Phase 5 Complete!"
 1140 IF S1$="AQC!" AND S2$="XPZ@" THEN PRINT "ALL TESTS PASSED" ELSE PRINT "SOME TESTS FAILED"
 1150 PRINT "==================================="
 1160 END

