REM filename: CHUCK2
REM Chuck Norris Jokes Fetcher - FN-ROM version

DIM jsonValue 400
DIM c$(11)

c$(0)="animal"
c$(1)="career"
c$(2)="celebrity"
c$(3)="dev"
c$(4)="fashion"
c$(5)="food"
c$(6)="history"
c$(7)="movie"
c$(8)="music"
c$(9)="science"
c$(10)="sport"
c$(11)="travel"

ttRow%=0
ttCol%=0
ttWord$=""
ttWordLen%=0
ttMaxRows%=13
ttOverflow%=FALSE

jsonValueLen%=0

CLS
PRINT "Initialising program..."

PROCfetch_joke

REPEAT
  PROCshow_joke_page
  PROCfetch_joke
  PROCwait_next_or_timeout
UNTIL FALSE
END

DEF PROCwait_next_or_timeout
LOCAL key%, done%

done%=FALSE
TIME=0
REPEAT
  key%=INKEY(1)
  IF key%=ASC("N") THEN done%=TRUE
  IF key%=ASC("n") THEN done%=TRUE
  IF TIME>=3000 THEN done%=TRUE
UNTIL done%
ENDPROC

DEF PROCpause(t%)
TIME=0
REPEAT UNTIL TIME>t%
ENDPROC

DEF PROCset_json_path(hndl%, path$)
  cmd$="FJSON "+STR$(hndl%)+" "+path$
  OSCLI cmd$
ENDPROC

DEF PROCfetch_joke
LOCAL handle%, cat%, url$

cat%=RND(12)-1
url$="https://api.chucknorris.io/jokes/random?category="+c$(cat%)

jsonValueLen%=0
handle%=OPENIN(url$)
IF handle%>=0 THEN PROCget_json(handle%, "/value")

ENDPROC

DEF PROCget_json(hndl%, path$)
  LOCAL max_size%, idx%, ch%, e%
  max_size%=400
  idx%=0
  PROCset_json_path(hndl%, path$)
  REPEAT
   ch%=BGET#hndl%
   e%=EOF#hndl%
   jsonValue?idx%=ch%
   idx%=idx%+1
  UNTIL e%=-1 OR idx%>=max_size%
  jsonValueLen%=idx%
  CLOSE# hndl%
ENDPROC

DEF PROCemptyResponse
PRINT TAB(3,8);"(no value parsed)";
ENDPROC

DEF PROCshowResponse
LOCAL i%, c%
FOR i%=0 TO jsonValueLen%-1
  c%=jsonValue?i%
  PROCtt_feed_char(c%)
NEXT

PROCtt_flush_word
IF ttOverflow% THEN PROCtt_overflow
ENDPROC

DEF PROCshow_joke_page
LOCAL row%
CLS: VDU 23,1,0;0;0;0;
PROCtt_header

PRINT TAB(0,7);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(173)+CHR$(174));CHR$(172);CHR$(189);
FOR row%=0 TO ttMaxRows%-1
  PRINT TAB(0,8+row%);CHR$(147);CHR$(238);CHR$(135);" ";STRING$(34," ");CHR$(147);CHR$(189);
NEXT
PRINT TAB(0,21);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(188)+CHR$(236));CHR$(172);CHR$(189);

PROCtt_footer
IF jsonValueLen%<=0 THEN PROCemptyResponse ELSE PROCshowResponse
PROCtt_reset_body

ENDPROC

DEF PROCtt_reset_body
ttRow%=0
ttCol%=0
ttWord$=""
ttWordLen%=0
ttOverflow%=FALSE
ttMaxRows%=13
ENDPROC

DEF PROCtt_header
PRINT TAB(0,0);
PRINT CHR$(148);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);
PRINT CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);
PRINT CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);
PRINT CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);CHR$(240);

PRINT CHR$(148);CHR$(157);CHR$(147);CHR$(252);CHR$(252);CHR$(252);CHR$(188);CHR$(172);CHR$(172);CHR$(180);
PRINT CHR$(160);CHR$(160);CHR$(168);CHR$(236);CHR$(172);CHR$(172);CHR$(180);CHR$(160);CHR$(160);CHR$(168);
PRINT CHR$(236);CHR$(172);CHR$(172);CHR$(180);CHR$(160);CHR$(160);CHR$(168);CHR$(236);CHR$(172);CHR$(188);
PRINT CHR$(180);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);

PRINT CHR$(148);CHR$(157);CHR$(147);CHR$(255);CHR$(255);CHR$(255);CHR$(181);CHR$(226);CHR$(255);CHR$(181);
PRINT CHR$(183);CHR$(235);CHR$(235);CHR$(234);CHR$(239);CHR$(160);CHR$(181);CHR$(247);CHR$(163);CHR$(251);
PRINT CHR$(234);CHR$(181);CHR$(234);CHR$(181);CHR$(183);CHR$(227);CHR$(251);CHR$(234);CHR$(172);CHR$(185);
PRINT CHR$(181);CHR$(247);CHR$(163);CHR$(251);CHR$(255);CHR$(255);CHR$(255);CHR$(160);CHR$(160);CHR$(160);

PRINT CHR$(148);CHR$(157);CHR$(147);CHR$(175);CHR$(175);CHR$(175);CHR$(173);CHR$(174);CHR$(175);CHR$(165);
PRINT CHR$(181);CHR$(170);CHR$(234);CHR$(170);CHR$(173);CHR$(172);CHR$(165);CHR$(191);CHR$(160);CHR$(239);
PRINT CHR$(170);CHR$(173);CHR$(174);CHR$(165);CHR$(181);CHR$(168);CHR$(239);CHR$(170);CHR$(172);CHR$(173);
PRINT CHR$(165);CHR$(255);CHR$(160);CHR$(255);CHR$(255);CHR$(255);CHR$(255);CHR$(160);CHR$(160);CHR$(160);

PRINT CHR$(148);CHR$(157);CHR$(147);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(160);CHR$(163);
PRINT CHR$(163);CHR$(163);CHR$(163);CHR$(160);CHR$(160);CHR$(160);CHR$(163);CHR$(163);CHR$(163);CHR$(163);
PRINT CHR$(160);CHR$(160);CHR$(160);CHR$(163);CHR$(163);CHR$(163);CHR$(163);CHR$(160);CHR$(160);CHR$(160);
PRINT CHR$(163);CHR$(163);CHR$(163);CHR$(163);CHR$(163);CHR$(163);CHR$(163);CHR$(160);CHR$(160);CHR$(160);

PRINT CHR$(132);CHR$(157);CHR$(135);CHR$(141);"     Chuck Norris API Demo          ";
PRINT CHR$(132);CHR$(157);CHR$(135);CHR$(141);"     Chuck Norris API Demo          ";
ENDPROC

DEF PROCtt_footer
PRINT TAB(0,23);
PRINT CHR$(129);CHR$(157);CHR$(134);" Press 'N' for next joke, or wait... ";
ENDPROC

DEF PROCtt_feed_char(c%)
IF ttOverflow% THEN GOTO 2500

IF c%=13 THEN PROCtt_flush_word:PROCtt_newline:GOTO 2500
IF c%=10 THEN PROCtt_flush_word:PROCtt_newline:GOTO 2500
IF c%=9 THEN c%=32
IF c%=32 THEN PROCtt_flush_word:GOTO 2500

ttWord$=ttWord$+CHR$(c%)
ttWordLen%=ttWordLen%+1

2500 REM end proc
ENDPROC

DEF PROCtt_flush_word
LOCAL needed%

IF ttOverflow% THEN GOTO 2700
IF ttWordLen%=0 THEN GOTO 2700

needed%=ttWordLen%
IF ttCol%>0 THEN needed%=needed%+1

IF ttCol%+needed%>35 THEN PROCtt_newline

IF ttOverflow% THEN GOTO 2700

IF ttCol%>0 THEN PROCtt_putc(32,ttRow%,ttCol%):ttCol%=ttCol%+1

PROCtt_puts(ttWord$,ttRow%,ttCol%)
ttCol%=ttCol%+ttWordLen%
ttWord$=""
ttWordLen%=0
2700 REM end proc
ENDPROC

DEF PROCtt_newline
ttRow%=ttRow%+1
ttCol%=0
IF ttRow%>=ttMaxRows% THEN ttOverflow%=TRUE
ENDPROC

DEF PROCtt_putc(c%,row%,col%)
IF row%<=13 AND col%<=34 THEN PRINT TAB(3+col%,8+row%);CHR$(c%);
ENDPROC

DEF PROCtt_puts(s$,row%,col%)
LOCAL k%
FOR k%=1 TO LEN(s$)
  PROCtt_putc(ASC(MID$(s$,k%,1)),row%,col%+k%-1)
NEXT
ENDPROC

DEF PROCtt_overflow
PRINT TAB(35,18);"...";
ENDPROC
