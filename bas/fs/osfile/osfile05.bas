REM filename: osf05
REM
REM -----------------------------------------------
REM DEMONSTRATION
REM -----------------------------------------------
REM OSFILE Update Lock Status
REM -----------------------------------------------

REM This program changes the lock status only for "Myself".
REM It changes it to locked.

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\      parameter block
.parms EQUW fname       \ address of filename string
       EQUD 0
       EQUD 0
       EQUD 0
       EQUB &A          \ new lock status
       EQUD 0
.parad EQUW parms       \ address of param block
.fname EQUS "Myself"    \ filename string
       EQUB &D          \ termination

.start LDA #4           \ specify lock status
       LDX parad        \ point X and Y
       LDY parad+1      \ at parms
       JSR osfile       \ call OSFILE
       RTS              \ bye bye
]
NEXT pass%
CALL start
*INFO Myself
END
