10 REM filename: SIMTEST
20 REM Simple test for FINDV/BGETV functionality - tests file opening and byte reading
30 
40 PRINT "=== Simple FINDV/BGETV Test ==="
50 PRINT
60 
70 REM Test opening HELLO file
80 PRINT "Testing file operations..."
90 PRINT
100 
110 REM Try to open HELLO file for reading
120 PRINT "Opening HELLO file..."
130 
140 REM Use OPENIN to open file for input
150 file% = OPENIN("HELLO")
160 
170 IF file% = 0 THEN PRINT "ERROR: Could not open HELLO" : GOTO 900
210 
220 PRINT "SUCCESS: Opened HELLO with handle "; file%
230 
240 REM Try to read some bytes using BGET#
250 PRINT
260 PRINT "Reading bytes from file..."
270 
280 FOR i% = 1 TO 20
290   REM Use BGET# to read a byte
300   byte% = BGET#file%
310   
320   IF EOF#file% THEN PRINT "EOF reached at byte "; i% : EXIT FOR
360   
370   PRINT "Byte "; i%; ": "; byte%; " ('"; CHR$(byte%); "')"
380 NEXT
390 
400 REM Close the file
410 PRINT
420 PRINT "Closing file..."
430 
440 CLOSE#file%
450 
460 PRINT "File closed"
470 
480 REM Test with WORLD file
490 PRINT
500 PRINT "Testing WORLD file..."
510 
520 file% = OPENIN("WORLD")
530 
540 IF file% = 0 THEN PRINT "ERROR: Could not open WORLD" : GOTO 900
580 
590 PRINT "SUCCESS: Opened WORLD with handle "; file%
600 
610 REM Read a few bytes
620 FOR i% = 1 TO 10
630   byte% = BGET#file%
640   
650   IF EOF#file% THEN PRINT "EOF reached at byte "; i% : EXIT FOR
690   
700   PRINT "Byte "; i%; ": "; byte%; " ('"; CHR$(byte%); "')"
710 NEXT
720 
730 REM Close WORLD
740 CLOSE#file%
750 
760 PRINT "WORLD file closed"
770 
780 PRINT
790 PRINT "=== Test completed ==="
800 
900 END
