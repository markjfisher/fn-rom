10 REM filename: 3TESTWR
20 REM Phase 3: Write and read back data
30 PRINT "Phase 3: Write and read test..."
40 REM --- Write phase ---
50 PRINT "Creating and writing to TFILE3..."
60 F=OPENOUT("TFILE3")
70 PRINT "File handle: ";F
80 REM Write "fenrock" (7 bytes)
90 BPUT#F,ASC("f")
100 BPUT#F,ASC("e")
110 BPUT#F,ASC("n")
120 BPUT#F,ASC("r")
130 BPUT#F,ASC("o")
140 BPUT#F,ASC("c")
150 BPUT#F,ASC("k")
160 PRINT "Written 7 bytes, PTR=";PTR#F;" EXT=";EXT#F
170 CLOSE#F
180 PRINT "File closed"
190 REM --- Read phase ---
200 PRINT "Opening and reading TFILE3..."
210 F=OPENIN("TFILE3")
220 PRINT "File handle: ";F
230 PRINT "Reading back: ";
240 FOR I=1 TO 7
250   B=BGET#F
260   PRINT CHR$(B);
270 NEXT I
280 PRINT
290 PRINT "PTR=";PTR#F;" EXT=";EXT#F
300 PRINT "EOF=";EOF#F
310 CLOSE#F
320 PRINT "Test complete!"
330 END

