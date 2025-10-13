10 REM filename: DELETE
15 REM Test file deletion through overwrite
20 PRINT "=== File Deletion Test ==="
30 PRINT "Creating TEMP1 file..."
40 file% = OPENOUT("TEMP1")
50 BPUT#file%, 65 : BPUT#file%, 66 : BPUT#file%, 67
60 CLOSE#file%
70 PRINT "*CAT should show TEMP1"
80 PRINT "Press any key to continue..."
90 GET key$
100 PRINT "Creating TEMP1 again (should delete old version)..."
110 file% = OPENOUT("TEMP1") 
120 BPUT#file%, 88 : BPUT#file%, 89 : BPUT#file%, 90
130 CLOSE#file%
140 PRINT "*CAT should still show only one TEMP1"
150 PRINT "Press any key to read contents..."
160 GET key$
170 file% = OPENIN("TEMP1")
180 PRINT "Contents: ";
190 WHILE NOT EOF#file%
200 byte% = BGET#file%
210 PRINT CHR$(byte%);
220 WEND
230 CLOSE#file%
240 PRINT
250 PRINT "Test complete!"
900 END
