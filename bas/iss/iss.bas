REM filename: iss
REM
REM Teletext ISS tracker via Fujinet OPENIN + FJSON

DEBUG%=FALSE

JSON_SIZE%=32
DIM jBuf JSON_SIZE%
jLen%=0

size%=1024
HIMEM=HIMEM-size%
GDATA%=HIMEM
DIM PATCH0% 6
DIM PATCH1% 6
DIM CODE% 200

ISS00%=46
ISS01%=56
ISS10%=38
ISS11%=60
SCREEN%=&7C00
X_CENTER%=19
Y_CENTER%=15

REM adjust for the hand created teletext map not being perfectly aligned to coordinates from API.

REM Horizontal tweak: negative moves ISS west (left), positive east (right)
X_ADJ%=-1

REM Vertical tweak: negative moves ISS north (up), positive south (down)
Y_ADJ%=-3

MAP_Y_MIN%=8
MAP_Y_MAX%=22
MAP_X_MAX%=36
OLDX%=-1
OLDY%=-1
ISSL%=4

fetch_ok%=FALSE
lat=0
lon=0
jNum=0

VDU 23,1,0;0;0;0;
CLS

IF DEBUG% THEN PROCdebug_on_error

IF DEBUG% THEN PRINT "ISS tracker debug mode" ELSE PRINT "Initialising data..."

PROCinit_globe

CLS
IF DEBUG%=FALSE THEN PROCshow_globe

REPEAT
  PROCfetch_iss_position
  IF DEBUG% THEN PROCshow_debug
  IF DEBUG%=FALSE THEN IF fetch_ok% THEN PROCupdate_iss_position
  PROCwait_refresh
UNTIL FALSE
END

DEF PROCdebug_on_error
ON ERROR PRINT "Error ";ERR;" line ";ERL : PROCnet_close_all : END
ENDPROC

DEF PROCinit_globe
MYSTR$="LOAD GDATA "+STR$~GDATA%
OSCLI MYSTR$
PROC_assemble
ENDPROC

DEF PROCwait_refresh
LOCAL key%, done%, w%

IF DEBUG% THEN w%=1000 ELSE w%=3000
done%=FALSE
TIME=0
REPEAT
  key%=INKEY(1)
  IF key%=ASC("N") THEN done%=TRUE
  IF key%=ASC("n") THEN done%=TRUE
  IF TIME>=w% THEN done%=TRUE
UNTIL done%
ENDPROC

DEF PROCset_json_path(hndl%, path$)
  cmd$="FJSON "+STR$(hndl%)+" "+path$
  OSCLI cmd$
ENDPROC

DEF PROCfetch_iss_position
LOCAL handle%, url$

url$="http://api.open-notify.org/iss-now.json"
jLen%=0
fetch_ok%=FALSE
handle%=0

IF DEBUG% THEN PROCdebug_on_error

IF DEBUG% THEN CLS
IF DEBUG% THEN PRINT "--- fetch ---"

IF DEBUG% THEN PRINT "OPENIN..."
handle%=OPENIN(url$)
IF DEBUG% THEN PRINT "  handle=";handle%
IF handle%=0 THEN PROCfail_fetch(0) : ENDPROC

IF DEBUG% THEN PRINT "FJSON latitude..."
PROCread_json_value(handle%, "/iss_position/latitude")
IF jLen%<=0 THEN PROCfail_fetch(handle%) : ENDPROC
IF DEBUG% THEN PROCprint_jbuf
PROCjbuf_val
lat=jNum
IF DEBUG% THEN PRINT "  lat=";lat

IF DEBUG% THEN PRINT "FJSON longitude..."
PROCread_json_value(handle%, "/iss_position/longitude")
IF jLen%<=0 THEN PROCfail_fetch(handle%) : ENDPROC
IF DEBUG% THEN PROCprint_jbuf
PROCjbuf_val
lon=jNum
IF DEBUG% THEN PRINT "  lon=";lon

IF DEBUG% THEN PRINT "CLOSE#";handle%
PROCtry_close_one(handle%)
IF DEBUG% THEN PROCdebug_on_error
fetch_ok%=TRUE
IF DEBUG% THEN PRINT "fetch_ok"
ENDPROC

DEF PROCshow_debug
PRINT "lat=";lat;" lon=";lon;
IF fetch_ok% THEN PRINT " ok=yes" ELSE PRINT " ok=no"
ENDPROC

DEF PROCtry_close_one(h%)
ON ERROR ENDPROC
CLOSE#h%
ENDPROC

DEF PROCnet_close_all
LOCAL h%
FOR h%=17 TO 21
  PROCtry_close_one(h%)
NEXT
ENDPROC

DEF PROCfail_fetch(h%)
IF h%>=17 THEN IF h%<=21 THEN PROCtry_close_one(h%)
IF DEBUG% THEN PROCdebug_on_error
IF DEBUG% THEN PRINT "fetch failed"
REM On failure leave the map and last ISS position on screen
ENDPROC

DEF PROCread_json_value(hndl%, path$)
LOCAL idx%, ch%, e%
idx%=0
IF DEBUG% THEN PRINT "  FJSON path=";path$
PROCset_json_path(hndl%, path$)
IF DEBUG% THEN PRINT "  BGET..."
REPEAT
  ch%=BGET#hndl%
  e%=EOF#hndl%
  IF e%<>-1 THEN jBuf?idx%=ch% : idx%=idx%+1
UNTIL e%=-1 OR idx%>=JSON_SIZE%
jLen%=idx%
IF DEBUG% THEN PRINT "  read len=";jLen%
ENDPROC

DEF PROCprint_jbuf
LOCAL i%, c%
PRINT "  value=[";
FOR i%=0 TO jLen%-1
  c%=jBuf?i%
  IF (c%>=48 AND c%<=57) OR c%=45 OR c%=46 THEN PRINT CHR$(c%);
NEXT
PRINT "] len=";jLen%
ENDPROC

DEF PROCjbuf_val
LOCAL i%, c%, neg%, whole%, frac%, fp%, dot%
neg%=1 : whole%=0 : frac%=0 : fp%=0 : dot%=0
FOR i%=0 TO jLen%-1
  c%=jBuf?i%
  IF c%=45 THEN neg%=-1
  IF c%=46 THEN dot%=1
  IF c%>=48 AND c%<=57 AND dot%=0 THEN whole%=whole%*10+c%-48
  IF c%>=48 AND c%<=57 AND dot% THEN frac%=frac%*10+c%-48 : fp%=fp%+1
NEXT
IF fp%=0 THEN jNum=neg%*whole% ELSE jNum=neg%*(whole%+frac%/10^fp%)
ENDPROC

DEF PROCupdate_iss_position
LOCAL iss_x%, iss_y%

iss_x%=X_CENTER%+INT(lon*4/36)+X_ADJ%
iss_y%=Y_CENTER%-INT(lat*4/45)+Y_ADJ%

IF iss_x%<0 THEN iss_x%=0
IF iss_x%>MAP_X_MAX% THEN iss_x%=MAP_X_MAX%
IF iss_y%<MAP_Y_MIN% THEN iss_y%=MAP_Y_MIN%
IF iss_y%>MAP_Y_MAX%-1 THEN iss_y%=MAP_Y_MAX%-1

PROCmove_iss(iss_x%, iss_y%)
ENDPROC

DEF PROCshow_globe
?(page_src%+1)=GDATA% MOD 256
?(page_src%+2)=GDATA% DIV 256
?(page_dst%+1)=SCREEN% MOD 256
?(page_dst%+2)=SCREEN% DIV 256
CALL copy%
ENDPROC

DEF PROCmove_iss(NEWX%, NEWY%)
IF OLDX%>=0 THEN PROCrestore_bg(OLDX%, OLDY%, ISSL%) : PROCrestore_bg(OLDX%, OLDY%+1, ISSL%)
PROCbuild_iss_patch2(NEWY%)
PROCpatch_line(PATCH0%, NEWX%, NEWY%, ISSL%)
PROCpatch_line(PATCH1%, NEWX%, NEWY%+1, ISSL%)
OLDX%=NEWX%
OLDY%=NEWY%
ENDPROC

DEF PROCbuild_iss_patch2(Y%)
LOCAL rowctl0%, rowctl1%

rowctl0%=GDATA%?(Y%*40)
rowctl1%=GDATA%?((Y%+1)*40)

PATCH0%?0=145
PATCH0%?1=ISS00%
PATCH0%?2=ISS01%
PATCH0%?3=rowctl0%

PATCH1%?0=145
PATCH1%?1=ISS10%
PATCH1%?2=ISS11%
PATCH1%?3=rowctl1%

ISSL%=4
ENDPROC

DEF PROCpatch_line(SRC%, X%, Y%, L%)
LOCAL dest%, i%
dest%=FNscr(X%, Y%)
FOR i%=0 TO L%-1
  ?(dest%+i%)=?(SRC%+i%)
NEXT
ENDPROC

DEF PROCrestore_bg(X%, Y%, L%)
LOCAL src%, dest%, i%
src%=FNbuf(X%, Y%)
dest%=FNscr(X%, Y%)
FOR i%=0 TO L%-1
  ?(dest%+i%)=?(src%+i%)
NEXT
ENDPROC

DEF FNscr(X%, Y%)=SCREEN%+Y%*40+X%
DEF FNbuf(X%, Y%)=GDATA%+Y%*40+X%

DEF PROC_assemble
FOR pass%=0 TO 2 STEP 2
  P%=CODE%
  [OPT pass%
  \ Simple, but fast 16 bit copy from src to dst
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
