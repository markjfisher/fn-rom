REM filename: weather

DIM jsonBuf% 127

DIM fcDate$(1)
DIM fcMax$(1)
DIM fcMin$(1)
DIM fcWind$(1)
DIM fcWindDeg$(1)
DIM fcCode$(1)
DIM fcRise$(1)
DIM fcSet$(1)

currentCity$="London"
statusLine$=""
fetchOk%=FALSE
mainImageLoaded%=FALSE
SCREEN%=0
geoHead$="https://geocoding-api.open-meteo.com/v1/search?name="
geoTail$="&count=1&language=en&format=json"
omHead$="https://api.open-meteo.com/v1/forecast?latitude="
omLon$="&longitude="
omQueryTail$="&timezone=auto&forecast_days=3&current=temperature_2m,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_direction_10m_dominant,sunrise,sunset"

finOsword%=&78
finMosOsword%=&FFF1
finReasonSetOpenUrl%=4
finOpenUrlSentinel$="://"
finStatusOk%=0

MODE 7
VDU 23,1,0;0;0;0;
PROCinit_screen

size%=1024
HIMEM=HIMEM-size%
IMAGE%=HIMEM

DIM CODE% 70
DIM finBuf% 512
DIM finBlock% 16
forecastLen%=0
PROC_assemble
PROCload_img("SUNIMG")
PROCshow_image

REPEAT
  PROCrefresh_weather(currentCity$)
  PROCwait_for_action
UNTIL FALSE
END

DEF PROCwait_for_action
LOCAL key%, nextCity$, done%
done%=FALSE
REPEAT
  key%=INKEY(5)
  IF key%=ASC("Q") OR key%=ASC("q") THEN PROCquit
  IF key%=ASC("R") OR key%=ASC("r") OR key%=ASC("N") OR key%=ASC("n") OR key%=32 THEN done%=TRUE
  IF key%=ASC("L") OR key%=ASC("l") THEN nextCity$=FNprompt_location : IF LEN(nextCity$)>0 THEN currentCity$=nextCity$ : done%=TRUE
UNTIL done%
ENDPROC

DEF PROCquit
CLS
VDU 23,1,1;0;0;0;
END
ENDPROC

DEF PROCmaster_init
OSCLI "*FX112,0"
OSCLI "*FX113,0"
ENDPROC

DEF PROCinit_screen
IF (INKEY(-256) AND &FF)=253 THEN PROCmaster_init
SCREEN%=?&350+256*?&351
ENDPROC

DEF PROCrefresh_weather(city$)
fetchOk%=FALSE
PROCclear_forecast_arrays
PROCstatus("Looking up "+city$)
IF FNlookup_location(city$)=FALSE THEN PROCshow_error(city$, "No matching location") : ENDPROC
PROCstatus("Fetching "+locName$)
IF FNfetch_weather_data=FALSE THEN PROCshow_error(locName$, "Unable to load weather") : ENDPROC
IF mainImageLoaded%=FALSE THEN PROCload_img("MAINIMG") : mainImageLoaded%=TRUE
PROCshow_image
fetchOk%=TRUE
PROCdraw_dashboard
ENDPROC

DEF FNlookup_location(city$)
LOCAL h%, ok%, query$
ok%=FALSE
query$=FNurl_encode(city$)
url$=geoHead$+query$+geoTail$
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
PROCjson_read(h%, "/results/0/name")
IF LEN(jsonValue$)=0 THEN CLOSE#h% : =FALSE
locName$=jsonValue$
PROCjson_read(h%, "/results/0/latitude")
locLat$=jsonValue$
PROCjson_read(h%, "/results/0/longitude")
locLon$=jsonValue$
PROCjson_read(h%, "/results/0/country_code")
locCountry$=jsonValue$
PROCjson_read(h%, "/results/0/admin1")
locState$=jsonValue$
IF locState$=locName$ THEN locState$=""
CLOSE#h%
PROCbuild_om_base
=TRUE

DEF PROCbuild_om_base
omBase$=omHead$+locLat$+omLon$+locLon$
ENDPROC

DEF PROCbuild_forecast_url
LOCAL n%
n%=LEN(omBase$)
$(finBuf%)=omBase$+CHR$(0)
$(finBuf%+n%)=omQueryTail$
forecastLen%=n%+LEN(omQueryTail$)
ENDPROC

DEF FNfetch_weather_data
LOCAL h%, i%, src%
PROCbuild_forecast_url
h%=FNfnnet_open_url(finBuf%, forecastLen%)
IF h%=0 THEN =FALSE
PROCjson_read(h%, "/current/temperature_2m")
weatherTemp$=jsonValue$
PROCjson_read(h%, "/current/wind_speed_10m")
weatherWind$=jsonValue$
PROCjson_read(h%, "/current/wind_direction_10m")
weatherWindDeg$=jsonValue$
PROCjson_read(h%, "/daily/sunrise/0")
weatherSunrise$=jsonValue$
PROCjson_read(h%, "/daily/sunset/0")
weatherSunset$=jsonValue$
FOR i%=0 TO 1
  src%=i%+1
  PROCjson_read(h%, "/daily/time/"+STR$(src%))
  fcDate$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/weather_code/"+STR$(src%))
  fcCode$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/temperature_2m_max/"+STR$(src%))
  fcMax$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/temperature_2m_min/"+STR$(src%))
  fcMin$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/wind_speed_10m_max/"+STR$(src%))
  fcWind$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/wind_direction_10m_dominant/"+STR$(src%))
  fcWindDeg$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/sunrise/"+STR$(src%))
  fcRise$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/sunset/"+STR$(src%))
  fcSet$(i%)=jsonValue$
NEXT
CLOSE#h%
=TRUE

DEF PROCjson_read(hndl%, path$)
LOCAL idx%, ch%, e%
jsonValue$=""
PROCset_json_path(hndl%, path$)
idx%=0
REPEAT
  e%=EOF#hndl%
  IF e%<>-1 THEN ch%=BGET#hndl% : IF idx%<128 THEN jsonBuf%?idx%=ch% : idx%=idx%+1
UNTIL e%=-1 OR idx%>=128
FOR I%=0 TO idx%-1
  jsonValue$=jsonValue$+CHR$(jsonBuf%?I%)
NEXT
ENDPROC

DEF PROCset_json_path(hndl%, path$)
LOCAL cmd$
cmd$="FJSON "+STR$(hndl%)+" "+path$
OSCLI cmd$
ENDPROC

DEF PROCdraw_dashboard
PROCdraw_current_panel
PROCdraw_outlook_panel
PROCdraw_status_keys
ENDPROC

DEF PROCdraw_current_panel
PRINT TAB(13,4);CHR$(131);FNpad(locName$,20);
PRINT TAB(13,5);CHR$(134);"Temp ";weatherTemp$;"C";
PRINT TAB(13,6);CHR$(132);"Wind ";FNtrim(weatherWind$);" ";FNwind_dir(weatherWindDeg$);
PRINT TAB(13,7);CHR$(135);"Sun ";FNtime_only(weatherSunrise$);"-";FNtime_only(weatherSunset$);
ENDPROC

DEF PROCdraw_outlook_panel
PROCdraw_day_column(2,12,0,"Tomorrow")
PROCdraw_day_column(21,12,1,"Next day")
ENDPROC

DEF PROCdraw_day_column(col%, row%, idx%, title$)
PRINT TAB(col%,row%);CHR$(131);title$;
PRINT TAB(col%,row%+1);CHR$(135);FNshort_date(fcDate$(idx%));"  ";FNshort_icon(VAL(fcCode$(idx%)));
PRINT TAB(col%,row%+3);CHR$(134);"High ";fcMax$(idx%);"C";
PRINT TAB(col%,row%+4);CHR$(134);"Low  ";fcMin$(idx%);"C";
PRINT TAB(col%,row%+6);CHR$(132);"Wind ";FNtrim(fcWind$(idx%));" ";FNwind_dir(fcWindDeg$(idx%));
PRINT TAB(col%,row%+7);CHR$(135);"Rise ";FNtime_only(fcRise$(idx%));
PRINT TAB(col%,row%+8);CHR$(135);"Set  ";FNtime_only(fcSet$(idx%));
ENDPROC

DEF PROCdraw_status_keys
PRINT TAB(4,23);CHR$(132);"L";CHR$(129);"ocn  ";CHR$(132);"R";CHR$(129);"efresh  ";CHR$(132);"Q";CHR$(129);"uit";
ENDPROC

DEF PROCshow_error(city$, msg$)
IF mainImageLoaded%=FALSE THEN PROCshow_image
PRINT TAB(13,4);CHR$(129);FNpad(city$,20);
PRINT TAB(13,5);CHR$(131);FNpad(msg$,20);
PRINT TAB(13,6);CHR$(135);"Use L or R";
PROCdraw_status_keys
ENDPROC

DEF PROCstatus(msg$)
PRINT TAB(4,23);CHR$(129);FNpad(msg$,35);
ENDPROC

DEF PROCclear_forecast_arrays
FOR I%=0 TO 1
  fcDate$(I%)=""
  fcMax$(I%)=""
  fcMin$(I%)=""
  fcWind$(I%)=""
  fcWindDeg$(I%)=""
  fcCode$(I%)=""
  fcRise$(I%)=""
  fcSet$(I%)=""
NEXT
ENDPROC

DEF FNprompt_location
LOCAL key%, done%, cancelled%
inputBuf$=currentCity$
done%=FALSE
cancelled%=FALSE
REPEAT
  PRINT TAB(4,23);CHR$(131);FNpad("Location: "+inputBuf$+"_",35);
  key%=GET
  IF key%=13 THEN done%=TRUE
  IF key%=27 THEN done%=TRUE : cancelled%=TRUE
  IF key%=127 OR key%=8 THEN IF LEN(inputBuf$)>0 THEN inputBuf$=LEFT$(inputBuf$,LEN(inputBuf$)-1)
  IF key%>=32 AND key%<=126 THEN IF LEN(inputBuf$)<24 THEN inputBuf$=inputBuf$+CHR$(key%)
UNTIL done%
IF cancelled% THEN =""
=FNtrim(inputBuf$)

DEF FNurl_encode(s$)
LOCAL out$, c$, i%
out$=""
FOR i%=1 TO LEN(s$)
  c$=MID$(s$,i%,1)
  IF c$=" " THEN out$=out$+"+" ELSE IF c$="," THEN out$=out$+"%2C" ELSE IF c$="#" THEN out$=out$+"%23" ELSE out$=out$+c$
NEXT
=out$

DEF FNtrim(s$)
LOCAL t$
t$=s$
REPEAT
  IF LEN(t$)>0 THEN IF LEFT$(t$,1)=" " THEN t$=MID$(t$,2)
UNTIL LEN(t$)=0 OR LEFT$(t$,1)<>" "
REPEAT
  IF LEN(t$)>0 THEN IF RIGHT$(t$,1)=" " THEN t$=LEFT$(t$,LEN(t$)-1)
UNTIL LEN(t$)=0 OR RIGHT$(t$,1)<>" "
=t$

DEF FNpad(s$, width%)
LOCAL t$
t$=s$
IF LEN(t$)>width% THEN =LEFT$(t$,width%)
=t$+STRING$(width%-LEN(t$)," ")

DEF FNtime_only(s$)
IF LEN(s$)>=16 THEN =MID$(s$,12,5)
=s$

DEF FNshort_date(s$)
IF LEN(s$)>=10 THEN =MID$(s$,9,2)+"/"+MID$(s$,6,2)
="--/--"

DEF FNwind_dir(deg$)
LOCAL d%, i%
IF LEN(deg$)=0 THEN ="--"
d%=VAL(deg$)
i%=(d%+22) DIV 45
IF i%=0 OR i%=8 THEN ="N"
IF i%=1 THEN ="NE"
IF i%=2 THEN ="E"
IF i%=3 THEN ="SE"
IF i%=4 THEN ="S"
IF i%=5 THEN ="SW"
IF i%=6 THEN ="W"
="NW"

DEF FNicon_kind(code%)
IF code%=0 THEN =0
IF code%=1 OR code%=2 OR code%=3 THEN =1
IF code%=51 OR code%=53 OR code%=55 OR code%=56 OR code%=57 OR code%=61 OR code%=63 OR code%=65 OR code%=66 OR code%=67 OR code%=80 OR code%=81 OR code%=82 THEN =2
IF code%=95 OR code%=96 OR code%=99 THEN =3
IF code%=71 OR code%=73 OR code%=75 OR code%=77 OR code%=85 OR code%=86 THEN =4
=5

DEF FNicon_label(code%)
LOCAL kind%
kind%=FNicon_kind(code%)
IF kind%=0 THEN ="SUNNY"
IF kind%=1 THEN ="CLOUD"
IF kind%=2 THEN ="RAIN"
IF kind%=3 THEN ="STORM"
IF kind%=4 THEN ="SNOW"
="FOG"

DEF FNshort_icon(code%)
LOCAL label$
label$=FNicon_label(code%)
=LEFT$(label$+"    ",8)

DEF PROCload_img(img$)
MYSTR$="LOAD "+img$+" "+STR$~IMAGE%
OSCLI MYSTR$
ENDPROC

DEF PROCshow_image
?(page_src%+1)=IMAGE% MOD 256
?(page_src%+2)=IMAGE% DIV 256
?(page_dst%+1)=SCREEN% MOD 256
?(page_dst%+2)=SCREEN% DIV 256
CALL copy%
ENDPROC

DEF PROC_assemble
FOR pass%=0 TO 2 STEP 2
  P%=CODE%
  [OPT pass%
  .copy
    LDA page_src+1 : STA rem_src+1
    LDA page_src+2 : STA rem_src+2
    LDA page_dst+1 : STA rem_dst+1
    LDA page_dst+2 : STA rem_dst+2

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

DEF PROCfnnet_set_open_url(addr%, len%)
IF len%>512 THEN ERROR 100,"String too long"
finBlock%?2=addr% AND &FF
finBlock%?3=addr% DIV 256
finBlock%?4=len% AND &FF
finBlock%?5=len% DIV 256
finBlock%?0=finReasonSetOpenUrl%
A%=finOsword%
X%=finBlock% MOD 256
Y%=finBlock% DIV 256
CALL finMosOsword%
ENDPROC

DEF FNfnnet_open_url(addr%, len%)
PROCfnnet_set_open_url(addr%, len%)
IF finBlock%?1<>finStatusOk% THEN =0
=OPENIN(finOpenUrlSentinel$)
