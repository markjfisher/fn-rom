10 REM filename: BPUTEST
15 REM BPUTV test: file creation, writing, reading verification
20 PRINT "=== BPUTV Test Program ==="
30 PRINT "Test 1: Creating and writing to TESTFILE..."
40 file% = OPENOUT("TESTFILE")
50 IF file% = 0 THEN PRINT "ERROR: Could not create TESTFILE" : GOTO 900
60 PRINT "Created TESTFILE, handle "; file%
70 PRINT "Writing test data..."
80 FOR i% = 65 TO 90
90 BPUT#file%, i%
100 PRINT "Wrote byte "; i%; " ("; CHR$(i%); ")"
110 NEXT
120 PRINT "Current PTR: "; PTR#file%
130 PRINT "Current EXT: "; EXT#file%
140 CLOSE#file%
150 PRINT "File closed"
160 PRINT "Test 2: Reading back written data..."
170 file% = OPENIN("TESTFILE")
180 IF file% = 0 THEN PRINT "ERROR: Could not open TESTFILE for reading" : GOTO 900
190 PRINT "Opened TESTFILE for reading, handle "; file%
200 errors% = 0
210 FOR i% = 65 TO 90
220 byte% = BGET#file%
230 IF byte% <> i% THEN PRINT "ERROR: Expected "; i%; ", got "; byte% : errors% = errors% + 1
240 NEXT
250 IF errors% = 0 THEN PRINT "SUCCESS: All "; (90-65+1); " bytes verified correctly"
260 IF errors% > 0 THEN PRINT "FAILED: "; errors%; " bytes were incorrect"
270 CLOSE#file%
280 PRINT "Test 3: Random access writing..."
290 file% = OPENUP("TESTFILE")
300 IF file% = 0 THEN PRINT "ERROR: Could not open TESTFILE for update" : GOTO 900
310 PRINT "Opened for update, EXT: "; EXT#file%
320 PTR#file% = 5
330 PRINT "Set PTR to 5, writing 'X' (88)"
340 BPUT#file%, 88
350 PTR#file% = 15
360 PRINT "Set PTR to 15, writing 'Y' (89)"
370 BPUT#file%, 89
380 CLOSE#file%
390 PRINT "Test 4: Verifying random access writes..."
400 file% = OPENIN("TESTFILE")
410 PTR#file% = 5
420 byte% = BGET#file%
430 IF byte% = 88 THEN PRINT "SUCCESS: Position 5 = 'X'" ELSE PRINT "ERROR: Position 5 = "; byte%
440 PTR#file% = 15
450 byte% = BGET#file%
460 IF byte% = 89 THEN PRINT "SUCCESS: Position 15 = 'Y'" ELSE PRINT "ERROR: Position 15 = "; byte%
470 CLOSE#file%
480 PRINT "All BPUTV tests completed!"
900 END
