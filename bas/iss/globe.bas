REM filename: globe
REM
REM Teletext picture viewer with fast ASM screen copy
REM and loading from GDATA file from disk.
REM This is a test application when transitioning from DATA statements
REM to loading into HIMEM from disk, freeing up program space

SCREEN%=0

REM MODE must come before HIMEM/DIM — MOS moves screen RAM and lowers HIMEM
MODE 7
CLS
VDU 23,1,0;0;0;0;
PROCinit_screen

size%=1024
HIMEM=HIMEM-size%
GDATA%=HIMEM

DIM CODE% 200

PRINT "Initialising data..."

MYSTR$="LOAD GDATA "+STR$~GDATA%
OSCLI MYSTR$
PROC_assemble

CLS
PROC_show

A%=GET
END

DEF PROCmaster_init
REM Master-only: VDU and CRTC must use main RAM or ?SCREEN% writes are invisible
OSCLI "*FX112,0"
OSCLI "*FX113,0"
ENDPROC

DEF PROCinit_screen
REM Master 128: INKEY(-256) low byte is 253 (&FD), not -6
IF (INKEY(-256) AND &FF)=253 THEN PROCmaster_init
REM MOS screen base at &350/&351 (moves if MODE 7 has scrolled)
SCREEN%=?&350+256*?&351
ENDPROC

DEF PROC_show
?(page_src%+1)=GDATA% MOD 256
?(page_src%+2)=GDATA% DIV 256

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
