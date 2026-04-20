REM filename: osa01
REM
REM ----------------------------------------------------
REM DEMONSTRATION
REM ----------------------------------------------------
REM OSARGS Current Filing System
REM ----------------------------------------------------

DIM code% &100
osargs = &FFDA

FOR pass% = 0 TO 2 STEP 2
P% = code%
[OPT pass%
.start LDA #0               \ specify get
       TAY                  \ filing system
       JSR osargs           \ call OSARGS
       STA &70              \ save filing system
       RTS                  \ bye bye
]
NEXT pass%
?&70 = 0

CLS
CALL start
PRINT "OSARGS value: "; ?&70
IF ?&70 = 4 PRINT "success" ELSE PRINT "fail"
END
