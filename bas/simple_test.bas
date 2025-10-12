10 REM filename: SIMTEST
40 PRINT "=== Simple FINDV/BGETV Test ==="
80 PRINT "Testing file operations..."
120 PRINT "Opening HELLO file..."
150 file = OPENIN("HELLO")
170 IF file = 0 THEN PRINT "ERROR: Could not open HELLO" : GOTO 900
220 PRINT "SUCCESS: Opened HELLO with handle "; file
260 PRINT "Reading bytes from file..."
280 FOR i% = 1 TO 200
300   byte% = BGET#file
320   PRINT "Byte "; i%; ": "; byte%; " ('"; CHR$(byte%); "')"
350   IF EOF#file THEN PRINT "EOF reached at byte "; i% : GOTO 420
380 NEXT
420 PRINT "Closing file..."
440 CLOSE#file
460 PRINT "File closed"
900 END
