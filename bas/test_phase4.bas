10 REM filename: 4MULTI
20 REM Phase 4: Multiple file handles - interleaved I/O
30 PRINT "Phase 4: Multi-file interleaved I/O..."
40 REM --- Write phase: interleaved ---
50 PRINT "Creating two files..."
60 F1=OPENOUT("FILE1")
70 F2=OPENOUT("FILE2")
80 PRINT "Handles: F1=";F1;" F2=";F2
90 PRINT "Writing interleaved data..."
100 REM Write 'a' to FILE1, 'Z' to FILE2
110 BPUT#F1,ASC("a")
120 BPUT#F2,ASC("Z")
130 REM Write 'b' to FILE1, 'Y' to FILE2
140 BPUT#F1,ASC("b")
150 BPUT#F2,ASC("Y")
160 REM Write 'c' to FILE1, 'X' to FILE2
170 BPUT#F1,ASC("c")
180 BPUT#F2,ASC("X")
190 PRINT "FILE1: PTR=";PTR#F1;" EXT=";EXT#F1
200 PRINT "FILE2: PTR=";PTR#F2;" EXT=";EXT#F2
210 PRINT "Closing files..."
220 CLOSE#F1
230 CLOSE#F2
240 PRINT "Files closed"
250 REM --- Read phase: interleaved ---
260 PRINT "Opening files for read..."
270 F1=OPENIN("FILE1")
280 F2=OPENIN("FILE2")
290 PRINT "Handles: F1=";F1;" F2=";F2
300 PRINT "Reading interleaved data..."
310 S1$=""
320 S2$=""
330 REM Read 1 byte from each file, 3 times
340 FOR I=1 TO 3
350   B1=BGET#F1
360   B2=BGET#F2
370   S1$=S1$+CHR$(B1)
380   S2$=S2$+CHR$(B2)
390 NEXT I
400 PRINT "FILE1 data: '";S1$;"'"
410 PRINT "FILE2 data: '";S2$;"'"
420 PRINT "FILE1: PTR=";PTR#F1;" EXT=";EXT#F1;" EOF=";EOF#F1
430 PRINT "FILE2: PTR=";PTR#F2;" EXT=";EXT#F2;" EOF=";EOF#F2
440 CLOSE#F1
450 CLOSE#F2
460 REM --- Verification ---
470 IF S1$="abc" AND S2$="ZYX" THEN PRINT "SUCCESS: Multi-file I/O works!" ELSE PRINT "FAILED: Data mismatch!"
480 END

