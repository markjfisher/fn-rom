10 REM filename: 2WRITE
20 REM Phase 2: File creation + write 32 bytes
30 PRINT "Phase 2: Creating file and writing data..."
40 F=OPENOUT("TFILE2")
50 PRINT "File handle: ";F
60 PRINT "Writing 32 bytes (A-Z + a-f)..."
70 FOR I=65 TO 90
80 BPUT#F,I
90 NEXT I
100 FOR I=97 TO 102
110 BPUT#F,I
120 NEXT I
130 PRINT "PTR: ";PTR#F
140 PRINT "EXT: ";EXT#F
150 CLOSE#F
160 PRINT "File closed"
170 END
