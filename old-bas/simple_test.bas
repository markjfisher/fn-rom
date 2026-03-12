10 REM filename: SIMTEST
40 PRINT "=== Simple FINDV/BGETV Test ==="
80 PRINT "Testing file operations..."
120 PRINT "Opening HELLO file..."
150 file = OPENIN("HELLO")
170 IF file = 0 THEN PRINT "ERROR: Could not open HELLO" : GOTO 900
220 PRINT "SUCCESS: Opened HELLO with handle "; file
260 PRINT "Reading bytes from file..."
270 i% = 0
280 REPEAT
300   byte% = BGET#file
310   i% = i% + 1
320   IF byte% >= 32 AND byte% <= 126 THEN char$ = CHR$(byte%) ELSE char$ = "."
330   PRINT "Byte "; i%; ": "; byte%; " ('"; char$; "')"
350 UNTIL EOF#file
360 PRINT "EOF reached at byte "; i%
420 PRINT "Closing file..."
440 CLOSE#file
460 PRINT "File closed"
900 END
