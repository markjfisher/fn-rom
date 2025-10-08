10 REM filename: FBGET
20 REM Test program for FINDV and BGETV functionality - tests file opening, byte reading, and EOF detection
30 REM
40 REM Test 1: Try to open HELLO file for reading
50 PRINT "=== FINDV/BGETV Test Program ==="
60 PRINT
70 PRINT "Test 1: Opening HELLO file for reading..."
80 
90 REM Open file for input using OPENIN
100 file% = OPENIN("HELLO")
110 
120 IF file% = 0 THEN PRINT "ERROR: Could not open HELLO" : GOTO 720
160 
170 PRINT "SUCCESS: Opened HELLO with handle "; file%
180 
190 REM Test 2: Read bytes from the file
200 PRINT
210 PRINT "Test 2: Reading bytes from file..."
220 
230 byte_count% = 0
240 REPEAT
250   byte% = BGET#file%
260   IF NOT EOF#file% THEN byte_count% = byte_count% + 1 : PRINT "Byte "; byte_count%; ": "; byte%; " ('"; CHR$(byte%); "')"
300 UNTIL EOF#file%
310 
320 PRINT "Total bytes read: "; byte_count%
330 
340 REM Test 3: Close the file
350 PRINT
360 PRINT "Test 3: Closing file..."
370 CLOSE#file%
380 PRINT "File closed successfully"
390 
400 REM Test 4: Try to open WORLD file
410 PRINT
420 PRINT "Test 4: Opening WORLD file for reading..."
430 
440 file% = OPENIN("WORLD")
450 
460 IF file% = 0 THEN PRINT "ERROR: Could not open WORLD" : GOTO 720
500 
510 PRINT "SUCCESS: Opened WORLD with handle "; file%
520 
530 REM Read a few bytes from WORLD
540 PRINT
550 PRINT "Reading first 10 bytes from WORLD:"
560 FOR i% = 1 TO 10
570   IF NOT EOF#file% THEN byte% = BGET#file% : PRINT "Byte "; i%; ": "; byte%; " ('"; CHR$(byte%); "')" ELSE PRINT "EOF reached at byte "; i% : EXIT FOR
640 NEXT
650 
660 CLOSE#file%
670 PRINT "WORLD file closed"
680 
690 PRINT
700 PRINT "=== All tests completed ==="
710 
720 END