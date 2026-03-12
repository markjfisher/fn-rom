10 REM filename: FBGET
15 REM Advanced FINDV/BGETV test: random access, multiple files, PTR manipulation
20 PRINT "=== Advanced FINDV/BGETV Tests ==="
30 PRINT "Test 1: Random access reading..."
40 file1% = OPENIN("HELLO")
50 IF file1% = 0 THEN PRINT "ERROR: Could not open HELLO" : GOTO 900
60 PRINT "Opened HELLO, handle "; file1%
70 PRINT "Reading byte 1: "; BGET#file1%
80 PRINT "Reading byte 2: "; BGET#file1%
90 PRINT "Current PTR: "; PTR#file1%
100 PRINT "Setting PTR to 66 (67th byte - expect 'HELLO')..."
110 PTR#file1% = 66
120 name$ = ""
130 FOR i% = 1 TO 5
140 name$ = name$ + CHR$(BGET#file1%)
150 NEXT
160 PRINT "Read string: '"; name$; "'"
170 IF name$ = "HELLO" THEN PRINT "SUCCESS: Found expected HELLO text" ELSE PRINT "ERROR: Expected 'HELLO', got '"; name$; "'"
180 PRINT "Test 2: Multiple files open..."
190 file2% = OPENIN("WORLD")
200 IF file2% = 0 THEN PRINT "ERROR: Could not open WORLD" : GOTO 850
210 PRINT "Opened WORLD, handle "; file2%
220 PRINT "Testing WORLD file string at byte 67..."
230 PTR#file2% = 66
240 name2$ = ""
250 FOR i% = 1 TO 5
260 name2$ = name2$ + CHR$(BGET#file2%)
270 NEXT
280 PRINT "Read string: '"; name2$; "'"
290 IF name2$ = "WORLD" THEN PRINT "SUCCESS: Found expected WORLD text" ELSE PRINT "ERROR: Expected 'WORLD', got '"; name2$; "'"
300 PRINT "Test 3: EOF and EXT testing..."
310 PRINT "HELLO EXT: "; EXT#file1%
320 PRINT "WORLD EXT: "; EXT#file2%
330 PTR#file1% = EXT#file1% - 1
340 PRINT "Set HELLO PTR to EXT-1, reading last byte: "; BGET#file1%
350 IF EOF#file1% THEN PRINT "EOF detected correctly" ELSE PRINT "ERROR: EOF not detected"
360 PRINT "Test 4: Seek and read patterns..."
370 PTR#file2% = 5
380 FOR i% = 1 TO 5
390 PRINT "Pos "; PTR#file2%; ": "; BGET#file2%
400 NEXT
410 PRINT "All tests completed successfully!"
420 CLOSE#file2%
430 PRINT "Closed WORLD"
440 CLOSE#file1%
450 PRINT "Closed HELLO"
460 GOTO 900
850 CLOSE#file1%
860 PRINT "Closed HELLO due to error"
900 END