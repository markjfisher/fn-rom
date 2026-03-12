10 REM filename: BASTST
20 REM Basic test for file operations - just tries to open HELLO file
30 
40 PRINT "Basic file test"
50 PRINT
60 
70 REM Try to open HELLO file using OPENIN
80 PRINT "Attempting to open HELLO file..."
90 
100 REM Use OPENIN to open file for input
110 file = OPENIN("HELLO")
120 PRINT "OPENIN returned: "; file
140 IF file=0 THEN PRINT "File open failed"
150 IF file<>0 THEN PRINT "File opened with handle: "; file : CLOSE#file : PRINT "File closed"
170 PRINT
180 PRINT "Test complete"
190 END
