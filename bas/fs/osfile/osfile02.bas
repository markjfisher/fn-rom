REM filename: osf02
REM
REM ---------------------------------------------
REM DEMONSTRATION
REM ---------------------------------------------
REM OSFILE Update Catalogue Entry
REM ---------------------------------------------

REM This program changes the catalogue entries for "Myself".
REM Change load address to &1900.
REM Change execute address to &191B.

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\      parameter block
.parms EQUW fname           \ address of filename string
       EQUD &1900           \ new load address
       EQUD &191B           \ new execute address
       EQUD 0
       EQUD 0
.parad EQUW parms           \ address of param block
.fname EQUS "Myself"        \ filename string
       EQUB &D              \ termination

.start LDA #1               \ specify update cat
       LDX parad            \ point X and Y
       LDY parad+1          \ at parms
       JSR osfile           \ call OSFILE
       RTS                  \ bye bye
]
NEXT pass%
CALL start
*INFO Myself
END
