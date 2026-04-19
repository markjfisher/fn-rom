REM filename: osf06
REM
REM ----------------------------------------------
REM DEMONSTRATION
REM ----------------------------------------------
REM OSFILE Read Catalogue For File
REM ----------------------------------------------

REM This program reads the catalogue entry for "Myself".
REM It then prints it.

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\ parameter block
.parms EQUW fname       \ address of filename string
       EQUD 0           \ DFS writes load address
       EQUD 0           \ DFS writes exec address
       EQUD 0           \ DFS writes file size
       EQUB 0           \ DFS writes lock status
       EQUD 0
.parad EQUW parms       \ address of param block
.fname EQUS "Myself"    \ filename string
       EQUB &D          \ termination

.start LDA #5           \ specify read cat
       LDX parad        \ point X and Y
       LDY parad+1      \ at parms
       JSR osfile       \ call OSFILE
       RTS              \ bye bye
]
NEXT pass%
CALL start
PRINT "load address = ";~parms!2
PRINT " xqt address = ";~parms!6
PRINT "size of file = ";~parms!10
REM advanced disk user guide says this should be "A" but I see "8"
PRINT " lock status = ";~parms?14
END
