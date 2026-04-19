REM filename: osf04
REM
REM -----------------------------------------------
REM DEMONSTRATION
REM -----------------------------------------------
REM OSFILE Update Execute Address
REM -----------------------------------------------

REM This program changes the execute address only for "Myself"
REM It changes it to &501B.

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\      parameter block
.parms EQUW fname       \ address of filename string
       EQUD 0
       EQUD &501B       \ new execute address
       EQUD 0
       EQUD 0
.parad EQUW parms       \ address of param block
.fname EQUS "Myself"    \ filename string
       EQUB &D          \ termination

.start LDA #3           \ specify xqt address
       LDX parad        \ point X and Y
       LDY parad+1      \ at parms
       JSR osfile       \ call OSFILE
       RTS              \ bye bye
]
NEXT pass%
CALL start
*INFO Myself
END
