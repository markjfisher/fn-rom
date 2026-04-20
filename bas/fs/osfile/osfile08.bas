REM filename: osf08
REM
REM ----------------------------------------------------
REM DEMONSTRATION
REM ----------------------------------------------------
REM OSFILE Load File
REM ----------------------------------------------------

REM This program loads "Myself" at its default
REM load address of &5000.

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\      parameter block
.parms EQUW fname       \ address of filename string
       EQUD 0
       EQUB 1           \ Load flag
       EQUD 0
       EQUD 0
       EQUD 0
.parad EQUW parms       \ address of param block
.fname EQUS "Myself"    \ filename string
       EQUB &D          \ termination

.start LDA #&FF         \ specify load
       LDX parad        \ point X and Y
       LDY parad+1      \ at parms
       JSR osfile       \ call OSFILE
       RTS              \ bye bye
]
NEXT pass%
*OPT 1,2

CLS
CALL start
END
