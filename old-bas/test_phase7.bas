2 REM filename: 7REUSE
3 REM Test sector reuse after deletion
4 REM Expected: FILE3 should reuse sector 5 after FILE1 is deleted
10 REM Step 1: Create FILE1 and FILE2
20 PRINT "Step 1: Creating FILE1 and FILE2"
30 F%=OPENOUT("FILE1")
40 BPUT#F%,65
50 CLOSE#F%
60 F%=OPENOUT("FILE2")
70 BPUT#F%,66
80 CLOSE#F%
90 REM Step 2: Show catalog - should see sectors 5,6
100 PRINT "Step 2: Catalog (FILE1=005, FILE2=006)"
110 *INFO *
120 PRINT "Press a key to continue"
130 A$=GET$
140 REM Step 3: Delete FILE1
150 PRINT "Step 3: Deleting FILE1"
160 *DELETE FILE1
170 REM Step 4: Create FILE3
180 PRINT "Step 4: Creating FILE3"
190 F%=OPENOUT("FILE3")
200 BPUT#F%,67
210 CLOSE#F%
220 REM Step 5: Show catalog - FILE3 should be at sector 5
230 PRINT "Step 5: Catalog (FILE3 should reuse sector 005)"
240 *INFO *
250 REM Check result
260 PRINT "If FILE3 is at sector 005, test PASSED"
270 PRINT "If FILE3 is at sector 007, test FAILED (no reuse)"
