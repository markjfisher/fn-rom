REM filename: osf01
REM
REM ----------------------------------------------------
REM DEMONSTRATION
REM ----------------------------------------------------
REM OSFILE Save Memory Block
REM ----------------------------------------------------

REM This program assembles the code below, and then saves
REM just the machine-code bits of itself to a file, "Myself".

DIM code% &100
osfile = &FFDD

FOR pass% = 0 TO 2 STEP 2
P% = code%
[ OPT pass%
\      parameter block
.parms EQUW fname           \ address of filename string
       EQUD parms           \ load address
       EQUD start           \ execute address
       EQUD parms           \ save start address
       EQUD end             \ save end address
.parad EQUW parms           \ address of param block
.fname EQUS "Myself"        \ filename string
       EQUB &D              \ termination

.start LDA #0               \ specify save
       LDX parad            \ point X and Y
       LDY parad+1          \ at parms
       JSR osfile           \ call OSFILE
       RTS                  \ bye bye
.end   EQUB 0               \ dummy byte
]

NEXT pass%
CALL start
*INFO Myself
END
