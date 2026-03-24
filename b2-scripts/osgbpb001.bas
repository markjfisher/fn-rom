10 REM CALL example
20 MODE 7
30 osgbpb = &FFD1
40 DIM conblok 11
50 DIM reply 13
51 PRINT ~(conblok MOD 256), ~(conblok DIV 256)
52 PRINT ~(reply MOD 256), ~(reply DIV 256)
53 PRINT "CALLING osgbpb"
54 PRINT "..."
55 FOR I%=0 TO 2000: NEXT I%
60 conblok!1 = reply
70 A% = 5
80 X% = conblok MOD 256
90 Y% = conblok DIV 256
100 CALL osgbpb
110 A$=""
120 FOR I% = 1 TO ?reply
130 A$ = A$ + CHR$(reply?I%)
140 NEXT
150 PRINT A$
160 END
