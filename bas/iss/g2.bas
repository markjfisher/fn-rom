REM filename: g2
REM Teletext picture viewer with fast ASM screen copy
REM and loading from GDATA file from disk

size%=2000
HIMEM=HIMEM-size%
GDATA%=HIMEM

DIM CODE% 200

SCREEN%=&7C00
VDU 23,1,0;0;0;0;
CLS
PRINT "Initialising data..."

MYSTR$="LOAD GDATA "+MID$(STR$~GDATA%,2)
PRINT ":";MYSTR$
OSCLI MYSTR$

PROC_assemble

CLS
PROC_show

A%=GET
END

DEF PROC_show
?(page_src%+1)=GDATA MOD 256
?(page_src%+2)=GDATA DIV 256

?(page_dst%+1)=SCREEN% MOD 256
?(page_dst%+2)=SCREEN% DIV 256

CALL copy%
ENDPROC

DEF PROC_assemble
FOR pass%=0 TO 2 STEP 2
  P%=CODE%
  [OPT pass%
  .copy
    LDA page_src+1
    STA rem_src+1
    LDA page_src+2
    STA rem_src+2
    LDA page_dst+1
    STA rem_dst+1
    LDA page_dst+2
    STA rem_dst+2

    LDX #3

  .page_loop_outer
    LDY #0

  .page_loop_inner
  .page_src
    LDA &FFFF,Y
  .page_dst
    STA &FFFF,Y
    INY
    BNE page_loop_inner

    INC page_src+2
    INC rem_src+2
    INC page_dst+2
    INC rem_dst+2

    DEX
    BNE page_loop_outer

    LDY #0

  .rem_loop
  .rem_src
    LDA &FFFF,Y
  .rem_dst
    STA &FFFF,Y
    INY
    CPY #232
    BNE rem_loop

    RTS
  ]
NEXT

copy%=copy
page_src%=page_src
page_dst%=page_dst
ENDPROC
