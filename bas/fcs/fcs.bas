REM 5 Card Stud - BBC Micro + FujiNet
REM MODE 1: 320x256, 4 colours, 20 cols x 32 rows text
REM GPLv3 - T.Cherryhomes, E.Carr, M.Fisher

MODE 129
VDU 23,1,0;0;0;0;
COLOUR 128+0:COLOUR 3:CLS

DIM jBuf% 127

serverEndpoint$="https://5card.carr-designs.com/"
query$="":myName$=""
rnd%=0:pot%=0:actP%=0:view%=0:mtime%=0
lastResult$=""
vmCount%=0:plCount%=0
prevRnd%=99:prevPlCount%=0
reqMove$="":errCount%=0:noanim%=0
curCard%=0:xOff%=0:prevPot%=0:waitCnt%=0
wasView%=255

DIM vmCode$(4):DIM vmName$(4)
DIM plN$(7),plS%(7),plB%(7),plM$(7),plP%(7),plH$(7)
DIM tblId$(7),tblN$(7),tblP$(7)
tblCount%=0

REM Player layout - master arrays (8 slots, indexed by position)
REM Scaled from MSX 32x24 to BBC 20x32

DIM plXm%(7),plYm%(7),plDm%(7),plBXm%(7),plBYm%(7)
DIM plX%(7),plY%(7),plD%(7),plBX%(7),plBY%(7)

REM X positions: player 0=bottom-centre, 1-3=left side,
REM 4=top-centre, 5-7=right side
FOR i%=0 TO 7:READ plXm%(i%):NEXT
FOR i%=0 TO 7:READ plYm%(i%):NEXT
FOR i%=0 TO 7:READ plDm%(i%):NEXT
FOR i%=0 TO 7:READ plBXm%(i%):NEXT
FOR i%=0 TO 7:READ plBYm%(i%):NEXT

DATA 7,0,0,0,7,17,17,17
DATA 24,23,15,5,4,5,15,23
DATA 1,1,1,1,1,-1,-1,-1
DATA 3,8,8,8,3,-6,-6,-6
DATA -3,-3,0,4,4,4,0,-3

REM playerCountIndex: for each player count (2-8), which master
REM slots to assign to logical players 0..playerCount-1
DIM plCI%(55)
FOR i%=0 TO 55:READ plCI%(i%):NEXT

DATA 0,4,0,0,0,0,0,0
DATA 0,2,6,0,0,0,0,0
DATA 0,2,4,6,0,0,0,0
DATA 0,2,3,5,6,0,0,0
DATA 0,2,3,4,5,6,0,0
DATA 0,2,3,4,5,6,7,0
DATA 0,1,2,3,4,5,6,7

REM Main

PROCwelcome
PROCselect_table

REPEAT
  PROCcall_server
  IF errCount%=0 THEN PROCupdate_screen:PROCwait_move
  IF errCount%<>0 THEN PROCpause(10)
  IF LEN(reqMove$)=0 THEN PROCpause(20)
UNTIL FALSE
END

DEF FNopen_url(url$)
=OPENIN(url$)

DEF PROCjpath(h%,path$)
LOCAL cmd$
cmd$="FJSON "+STR$(h%)+" "+path$
OSCLI cmd$
ENDPROC

DEF FNjread(h%,path$)
LOCAL idx%,ch%,e%,jv$,k%
jv$="":idx%=0
PROCjpath(h%,path$)
REPEAT
  e%=EOF#h%
  IF e%<>-1 THEN ch%=BGET#h%:jBuf%?idx%=ch%:idx%=idx%+1
UNTIL e%=-1 OR idx%>=127
FOR k%=0 TO idx%-1:jv$=jv$+CHR$(jBuf%?k%):NEXT
=jv$

DEF PROCapi_call(path$)
LOCAL url$,h%
url$=serverEndpoint$+path$+query$
h%=FNopen_url(url$)
IF h%=0 THEN errCount%=errCount%+1:IF errCount%>1 THEN PROCstatus("CONNECTING..."):ENDPROC
PROCload_state(h%,path$="tables")
CLOSE#h%
errCount%=0
ENDPROC

DEF PROCcall_server
LOCAL path$
IF LEN(reqMove$)>0 THEN path$="move/"+reqMove$:reqMove$=""
IF LEN(reqMove$)=0 THEN path$="state"
PROCapi_call(path$)
ENDPROC

DEF PROCload_state(h%,isTbl%)
LOCAL i%,done%,jn$,jm$

IF isTbl% THEN tblCount%=0:done%=FALSE:i%=0
IF isTbl% THEN REPEAT
IF isTbl% THEN jn$=FNjread(h%,"/"+FNnum(i%)+"/n")
IF isTbl% THEN IF LEN(jn$)=0 THEN done%=TRUE
IF isTbl% THEN IF tblCount%>7 THEN done%=TRUE
IF isTbl% THEN IF LEN(jn$)<>0 THEN IF NOT done% THEN tblN$(tblCount%)=jn$
IF isTbl% THEN IF LEN(jn$)<>0 THEN IF NOT done% THEN tblId$(tblCount%)=FNjread(h%,"/"+FNnum(i%)+"/t")
IF isTbl% THEN IF LEN(jn$)<>0 THEN IF NOT done% THEN tblP$(tblCount%)=FNjread(h%,"/"+FNnum(i%)+"/p")
IF isTbl% THEN IF LEN(jn$)<>0 THEN IF NOT done% THEN tblCount%=tblCount%+1:i%=i%+1
IF isTbl% THEN UNTIL done% OR i%>7
IF isTbl% THEN ENDPROC

rnd%=VAL(FNjread(h%,"/r"))
pot%=VAL(FNjread(h%,"/p"))
actP%=VAL(FNjread(h%,"/a"))
view%=VAL(FNjread(h%,"/v"))
mtime%=VAL(FNjread(h%,"/m"))
lastResult$=FNjread(h%,"/l")

vmCount%=0:done%=FALSE:i%=0
REPEAT
  jm$=FNjread(h%,"/vm/"+FNnum(i%)+"/m")
  IF LEN(jm$)=0 THEN done%=TRUE
  IF vmCount%>4 THEN done%=TRUE
  IF LEN(jm$)<>0 THEN IF NOT done% THEN vmCode$(vmCount%)=jm$
  IF LEN(jm$)<>0 THEN IF NOT done% THEN vmName$(vmCount%)=FNjread(h%,"/vm/"+FNnum(i%)+"/n")
  IF LEN(jm$)<>0 THEN IF NOT done% THEN vmCount%=vmCount%+1:i%=i%+1
UNTIL done% OR i%>4

plCount%=0:done%=FALSE:i%=0
REPEAT
  jn$=FNjread(h%,"/pl/"+FNnum(i%)+"/n")
  IF LEN(jn$)=0 THEN done%=TRUE
  IF plCount%>7 THEN done%=TRUE
  IF LEN(jn$)<>0 THEN IF NOT done% THEN IF LEN(jn$)>8 THEN jn$=LEFT$(jn$,8)
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plN$(plCount%)=FNupper(jn$)
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plS%(plCount%)=VAL(FNjread(h%,"/pl/"+FNnum(i%)+"/s"))
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plB%(plCount%)=VAL(FNjread(h%,"/pl/"+FNnum(i%)+"/b"))
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plM$(plCount%)=FNupper(FNjread(h%,"/pl/"+FNnum(i%)+"/m"))
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plP%(plCount%)=VAL(FNjread(h%,"/pl/"+FNnum(i%)+"/p"))
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plH$(plCount%)=FNupper(FNjread(h%,"/pl/"+FNnum(i%)+"/h"))
  IF LEN(jn$)<>0 THEN IF NOT done% THEN plCount%=plCount%+1:i%=i%+1
UNTIL done% OR i%>7
ENDPROC

DEF PROCreset_screen
COLOUR 128+0:COLOUR 3:CLS
REM Draw table border (green)
COLOUR 2
PRINT TAB(0,0);STRING$(40,"=");
PRINT TAB(0,27);STRING$(40,"=");
COLOUR 3
ENDPROC

DEF PROCstatus(msg$)
LOCAL pad$
pad$=LEFT$(msg$+STRING$(40," "),40)
COLOUR 128+0:COLOUR 2
PRINT TAB(0,28);pad$;
COLOUR 128+0:COLOUR 3
ENDPROC

DEF PROCdrain_keys
LOCAL k%
REPEAT
  k%=INKEY(1)
UNTIL k%=-1
ENDPROC

DEF PROCclear_status
COLOUR 128+0:COLOUR 3
PRINT TAB(0,28);STRING$(40," ");
PRINT TAB(0,29);STRING$(40," ");
PRINT TAB(0,30);STRING$(40," ");
PRINT TAB(0,31);STRING$(40," ");
ENDPROC

REM Draw a single card (2 chars) at col%,row%
REM c$="AS","KH","??" etc.  fd%=1 means face down
DEF PROCcard(c$,col%,row%,fd%)
LOCAL s$
IF col%<0 OR col%>18 OR row%<1 OR row%>26 THEN ENDPROC
IF fd% THEN COLOUR 128+2:COLOUR 0:PRINT TAB(col%,row%);"??";
IF NOT fd% THEN s$=RIGHT$(c$,1)
IF NOT fd% THEN COLOUR 128+3
IF NOT fd% THEN IF s$="H" OR s$="D" THEN COLOUR 1
IF NOT fd% THEN IF s$<>"H" AND s$<>"D" THEN COLOUR 0
IF NOT fd% THEN PRINT TAB(col%,row%);LEFT$(c$,2);
COLOUR 128+0:COLOUR 3
ENDPROC

REM Render all player hands from current state
DEF PROCdraw_cards
LOCAL ci%,j%,ii%,i%,fd%,h$,col%,ff%
IF rnd%<1 THEN ENDPROC
ci%=0:xOff%=0
REPEAT
  ci%=ci%+1:j%=ci%*2-1
  FOR ii%=1 TO plCount%
    i%=ii% MOD plCount%
    IF LEN(plH$(i%))>j% THEN h$=MID$(plH$(i%),j%,2)
    IF LEN(plH$(i%))>j% THEN fd%=(j%=1 AND i%=0 AND rnd%<5 AND NOT view%)
    IF LEN(plH$(i%))>j% THEN ff%=(i%=0 AND NOT view%)
    IF LEN(plH$(i%))>j% THEN IF ff% THEN col%=plX%(i%)+(j%-1)*plD%(i%)
    IF LEN(plH$(i%))>j% THEN IF NOT ff% THEN col%=plX%(i%)+xOff%*plD%(i%)
    IF LEN(plH$(i%))>j% THEN IF h$=".." OR h$="" THEN fd%=1:h$="??"
    IF LEN(plH$(i%))>j% THEN PROCcard(h$,col%,plY%(i%),fd%)
  NEXT
  xOff%=xOff%+1
  IF xOff%>1 THEN xOff%=xOff%+1
UNTIL ci%>rnd%
ENDPROC

REM Draw player names and purse amounts
DEF PROCdraw_names
LOCAL i%,x%,y%,p$,nlen%
FOR i%=0 TO plCount%-1
  x%=plX%(i%):y%=plY%(i%)
  p$=STR$(plP%(i%))
  IF i%>0 OR view% THEN nlen%=LEN(plN$(i%))
  IF i%>0 OR view% THEN IF plD%(i%)<0 THEN x%=x%-nlen%+1
  IF i%>0 OR view% THEN COLOUR 128+0
  IF i%>0 OR view% THEN IF actP%=i% THEN COLOUR 1
  IF i%>0 OR view% THEN IF actP%<>i% THEN COLOUR 3
  IF i%>0 OR view% THEN PRINT TAB(x%,y%-1);plN$(i%);
  IF i%=0 AND NOT view% THEN COLOUR 128+0:COLOUR 2:PRINT TAB(x%-3,y%+2);" YOU";
  COLOUR 128+0:COLOUR 1
  IF i%=0 THEN PRINT TAB(x%-2,y%-2);p$;"  ";
  IF i%<>0 THEN IF plD%(i%)<0 THEN PRINT TAB(x%-LEN(p$),y%-2);p$;"  ";
  IF i%<>0 THEN IF plD%(i%)>=0 THEN PRINT TAB(x%,y%-2);p$;"  ";
NEXT
COLOUR 128+0:COLOUR 3
ENDPROC

REM Draw bets and move labels near each player
DEF PROCdraw_bets
LOCAL i%,x%,y%,b$,m$
IF rnd%<1 OR rnd%>4 THEN ENDPROC
FOR i%=0 TO plCount%-1
  m$=LEFT$(plM$(i%)+"     ",5)
  x%=plX%(i%)+plBX%(i%):y%=plY%(i%)+plBY%(i%)
  IF plD%(i%)<0 THEN x%=x%-5
  IF x%>=0 AND x%<=15 AND y%>=1 AND y%<=26 THEN COLOUR 128+0:COLOUR 2:PRINT TAB(x%,y%);m$;
  IF plB%(i%)>0 THEN b$=STR$(plB%(i%))
  IF plB%(i%)>0 THEN x%=plX%(i%)+plBX%(i%):y%=plY%(i%)+plBY%(i%)+1
  IF plB%(i%)>0 THEN IF plD%(i%)<0 THEN x%=x%-LEN(b$)
  IF plB%(i%)>0 THEN IF x%>=0 AND x%<=18 AND y%>=1 AND y%<=26 THEN COLOUR 128+0:COLOUR 1:PRINT TAB(x%,y%);b$;" ";
NEXT
COLOUR 128+0:COLOUR 3
ENDPROC

REM Draw pot in centre of screen
DEF PROCdraw_pot
COLOUR 128+0:COLOUR 2
PRINT TAB(7,2);"POT:";
COLOUR 1
PRINT pot%;"   ";
COLOUR 2
PRINT " RND:";rnd%;" ";
COLOUR 3
ENDPROC

REM Update player position arrays based on current plCount%
DEF PROCsetup_positions
LOCAL i%,j%,n%,base%
IF plCount%<2 THEN ENDPROC
base%=(plCount%-2)*8
FOR i%=0 TO plCount%-1
  n%=plCI%(base%+i%)
  plX%(i%)=plXm%(n%):plY%(i%)=plYm%(n%)
  plD%(i%)=plDm%(n%):plBX%(i%)=plBXm%(n%):plBY%(i%)=plBYm%(n%)
NEXT
ENDPROC

REM Game status message (waiting / result)
DEF PROCdraw_status
IF actP%=0 AND NOT view% THEN ENDPROC
IF actP%>0 THEN PROCstatus("WAITING ON "+plN$(actP%))
IF actP%<=0 THEN IF (actP%<0) AND (rnd%=5 OR rnd%=0) THEN PROCstatus(LEFT$(lastResult$,20))
IF rnd%=0 THEN waitCnt%=(waitCnt%+1) MOD 4
IF rnd%=0 THEN COLOUR 128+0:COLOUR 2
IF rnd%=0 THEN PRINT TAB(16,28);MID$(". . . . ",waitCnt%*2+1,1);" ";
IF rnd%=0 THEN COLOUR 3
ENDPROC

REM Full screen redraw
DEF PROCupdate_screen
IF plCount%<>prevPlCount% THEN IF plCount%>1 AND prevPlCount%>0 THEN IF plCount%<prevPlCount% THEN PROCstatus("A PLAYER LEFT THE TABLE")
IF plCount%<>prevPlCount% THEN IF plCount%>1 AND prevPlCount%>0 THEN IF plCount%>=prevPlCount% THEN lastResult$="A NEW PLAYER JOINS":PROCstatus(lastResult$)
IF plCount%<>prevPlCount% THEN IF plCount%>1 AND prevPlCount%>0 THEN PROCpause(40)
IF plCount%<>prevPlCount% THEN IF plCount%>1 AND prevPlCount%>0 THEN IF rnd%>1 THEN noanim%=1
IF plCount%<>prevPlCount% THEN prevPlCount%=plCount%:PROCsetup_positions

IF view%<>wasView% THEN IF view% THEN PROCstatus("TABLE FULL: SPECTATING"):PROCpause(80)
IF view%<>wasView% THEN wasView%=view%

IF rnd%<prevRnd% THEN xOff%=0:curCard%=0:prevPot%=0
IF rnd%<prevRnd% THEN IF rnd%>1 THEN noanim%=1

PROCreset_screen
PROCdraw_pot
IF plCount%>1 THEN PROCdraw_names:PROCdraw_bets:PROCdraw_cards
PROCdraw_status
prevRnd%=rnd%
ENDPROC

DEF PROCwait_move
LOCAL k%,sel%,i%,x%,moved%
reqMove$=""
IF view% OR actP%<>0 THEN ENDPROC
IF vmCount%=0 THEN ENDPROC

PROCclear_status
sel%=(vmCount%>1)

REM Draw move options on row 30
COLOUR 128+0:COLOUR 3
PRINT TAB(0,30);STRING$(20," ");
PRINT TAB(20,30);STRING$(20," ");
x%=0
FOR i%=0 TO vmCount%-1
  IF i%=sel% THEN COLOUR 1
  IF i%<>sel% THEN COLOUR 3
  PRINT TAB(x%,30);vmName$(i%);"  ";
  x%=x%+LEN(vmName$(i%))+2
NEXT
COLOUR 3

REM Timer display
PRINT TAB(17,31);STRING$(3," ");
PRINT TAB(17,31);mtime%;" ";

moved%=FALSE
REPEAT
  k%=INKEY(2)

  IF k%=ASC(",") OR k%=136 OR k%=122 THEN IF sel%>0 THEN sel%=sel%-1:PROCdraw_move_opts(sel%)
  IF k%=ASC(".") OR k%=137 OR k%=120 THEN IF sel%<vmCount%-1 THEN sel%=sel%+1:PROCdraw_move_opts(sel%)
  IF k%=13 OR k%=32 THEN moved%=TRUE
  IF k%=27 THEN PROCingame_menu:ENDPROC

  mtime%=mtime%-1
  IF mtime%>0 THEN PRINT TAB(17,31);mtime%;"  ";
UNTIL moved% OR mtime%<1

IF moved% AND sel%<vmCount% THEN reqMove$=vmCode$(sel%)
PROCclear_status
ENDPROC

DEF PROCdraw_move_opts(sel%)
LOCAL i%,x%
x%=0
COLOUR 128+0
PRINT TAB(0,30);STRING$(20," ");
PRINT TAB(20,30);STRING$(20," ");
FOR i%=0 TO vmCount%-1
  IF i%=sel% THEN COLOUR 1
  IF i%<>sel% THEN COLOUR 3
  PRINT TAB(x%,30);vmName$(i%);"  ";
  x%=x%+LEN(vmName$(i%))+2
NEXT
COLOUR 3
ENDPROC

DEF PROCselect_table
LOCAL k%,sel%,done%,i%
IF LEN(query$)>0 THEN ENDPROC
done%=FALSE:sel%=0

REPEAT
  PROCreset_screen
  PROCstatus("REFRESHING TABLE LIST...")
  PROCapi_call("tables")

  PROCreset_screen
  COLOUR 128+0:COLOUR 2
  PRINT TAB(1,3);"CHOOSE A TABLE TO JOIN";
  COLOUR 3
  PRINT TAB(0,5);"TABLE           PLRS";
  PRINT TAB(0,6);STRING$(20,"-");
  FOR i%=0 TO tblCount%-1
    PRINT TAB(1,7+i%*2);LEFT$(tblN$(i%)+"                ",16);
    PRINT TAB(17,7+i%*2);tblP$(i%);
  NEXT
  IF tblCount%=0 THEN PRINT TAB(2,9);"NO TABLES FOUND";
  COLOUR 2
  PRINT TAB(0,28);"R-EFRESH  H-ELP  Q-UIT";
  COLOUR 3
  IF tblCount%>0 THEN PRINT TAB(0,7+sel%*2);">";
  PROCdrain_keys

  done%=FALSE
  REPEAT
    k%=GET
    IF k%=ASC("R") OR k%=ASC("r") THEN done%=TRUE
    IF k%=ASC("H") OR k%=ASC("h") THEN PROChow_to_play:done%=TRUE
    IF k%=ASC("Q") OR k%=ASC("q") THEN PROCquit
    IF k%=ASC("N") OR k%=ASC("n") THEN PROCget_name:done%=TRUE
    IF tblCount%>0 AND (k%=ASC("j") OR k%=248 OR k%=10) THEN PRINT TAB(0,7+sel%*2);" ";
    IF tblCount%>0 AND (k%=ASC("j") OR k%=248 OR k%=10) THEN IF sel%>0 THEN sel%=sel%-1
    IF tblCount%>0 AND (k%=ASC("j") OR k%=248 OR k%=10) THEN PRINT TAB(0,7+sel%*2);">";
    IF tblCount%>0 AND (k%=ASC("k") OR k%=250 OR k%=11) THEN PRINT TAB(0,7+sel%*2);" ";
    IF tblCount%>0 AND (k%=ASC("k") OR k%=250 OR k%=11) THEN IF sel%<tblCount%-1 THEN sel%=sel%+1
    IF tblCount%>0 AND (k%=ASC("k") OR k%=250 OR k%=11) THEN PRINT TAB(0,7+sel%*2);">";
    IF tblCount%>0 AND (k%=13 OR k%=32) THEN query$="?table="+tblId$(sel%)
    IF tblCount%>0 AND (k%=13 OR k%=32) THEN PRINT TAB(1,16);"JOINING: ";tblN$(sel%);
    IF tblCount%>0 AND (k%=13 OR k%=32) THEN PROCstatus("CONNECTING TO SERVER...")
    IF tblCount%>0 AND (k%=13 OR k%=32) THEN done%=TRUE
  UNTIL done%
UNTIL LEN(query$)>0

query$=query$+"&player="+FNurl_encode(myName$)
ENDPROC

DEF PROCwelcome
PROCreset_screen
COLOUR 128+0:COLOUR 2
PRINT TAB(2,4);"**** 5 CARD STUD ****";
PRINT TAB(3,6);"BBC MICRO + FUJINET";
COLOUR 3
PRINT TAB(2,8);"Multi-player poker over";
PRINT TAB(2,9);"the FujiNet!";
PROCpause(30)
PROCget_name
ENDPROC

DEF PROCget_name
LOCAL k%,done%
PROCreset_screen
COLOUR 128+0:COLOUR 2
PRINT TAB(2,8);"ENTER YOUR NAME (1-8 CHARS)";
COLOUR 3
PRINT TAB(2,11);"[        ]";
myName$="":done%=FALSE
REPEAT
  PRINT TAB(3,11);LEFT$(myName$+"        ",8);"_";
  k%=GET
  IF k%=13 AND LEN(myName$)>0 THEN done%=TRUE
  IF (k%=127 OR k%=8) AND LEN(myName$)>0 THEN myName$=LEFT$(myName$,LEN(myName$)-1)
  IF k%>=32 AND k%<=126 AND LEN(myName$)<8 THEN IF k%>=97 AND k%<=122 THEN k%=k%-32
  IF k%>=32 AND k%<=126 AND LEN(myName$)<8 THEN myName$=myName$+CHR$(k%)
UNTIL done%
COLOUR 128+0:COLOUR 2
PRINT TAB(2,13);"WELCOME, ";myName$;"!";
COLOUR 3
PROCpause(30)
ENDPROC

DEF PROCingame_menu
LOCAL k%,done%
done%=FALSE
COLOUR 128+0:COLOUR 3
PRINT TAB(2,10);STRING$(16,"=");
PRINT TAB(2,11);"  Q: QUIT TABLE  ";
PRINT TAB(2,12);"  H: HOW TO PLAY ";
PRINT TAB(2,13);" ESC: KEEP PLAYING";
PRINT TAB(2,14);STRING$(16,"=");
REPEAT
  k%=GET
  IF k%=ASC("Q") OR k%=ASC("q") THEN PROCstatus("LEAVING TABLE..."):PROCapi_call("leave"):query$="":PROCselect_table:done%=TRUE
  IF k%=ASC("H") OR k%=ASC("h") THEN PROChow_to_play:done%=TRUE
  IF k%=27 THEN done%=TRUE
UNTIL done%
ENDPROC

DEF PROChow_to_play
PROCreset_screen
COLOUR 128+0:COLOUR 2
PRINT TAB(1,2);"HOW TO PLAY 5 CARD STUD";
COLOUR 3
PRINT TAB(0,4);"Players are dealt 5 cards";
PRINT TAB(0,5);"over 4 betting rounds.";
PRINT TAB(0,7);"MOVES:";
PRINT TAB(0,9);"FOLD   Quit the hand";
PRINT TAB(0,10);"CHECK  Free pass (no bet)";
PRINT TAB(0,11);"BET    Place a bet";
PRINT TAB(0,12);"RAISE  Increase the bet";
PRINT TAB(0,13);"CALL   Match current bet";
PRINT TAB(0,15);"Use LEFT/RIGHT or Z/X";
PRINT TAB(0,16);"to select. RETURN to";
PRINT TAB(0,17);"confirm your move.";
COLOUR 2
PRINT TAB(2,30);"PRESS A KEY TO CONTINUE";
COLOUR 3
LOCAL k%
k%=GET
PROCreset_screen
ENDPROC

DEF PROCpause(n%)
LOCAL t%
t%=TIME+n%*2
REPEAT UNTIL TIME>=t%
ENDPROC

DEF PROCquit
CLS:VDU 23,1,1;0;0;0;:END
ENDPROC

DEF FNupper(s$)
LOCAL i%,c%,r$
r$=""
FOR i%=1 TO LEN(s$)
  c%=ASC(MID$(s$,i%,1))
  IF c%>=97 AND c%<=122 THEN c%=c%-32
  r$=r$+CHR$(c%)
NEXT
=r$

DEF FNnum(n%)
LOCAL s$
s$=STR$(n%)
IF LEFT$(s$,1)=" " THEN s$=MID$(s$,2)
=s$

DEF FNurl_encode(s$)
LOCAL out$,i%,c$
out$=""
FOR i%=1 TO LEN(s$)
  c$=MID$(s$,i%,1)
  IF c$=" " THEN out$=out$+"+"
  IF c$<>" " THEN out$=out$+c$
NEXT
=out$
