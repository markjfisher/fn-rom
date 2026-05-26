REM filename: weather
REM
REM ----------------------------------------------------
REM FujiNet Open-Meteo weather dashboard for BBC Micro
REM ----------------------------------------------------

DIM jsonBuf% 127

DIM fcDate$(7)
DIM fcMax$(7)
DIM fcMin$(7)
DIM fcWind$(7)
DIM fcWindDeg$(7)
DIM fcRain$(7)
DIM fcUv$(7)
DIM fcCode$(7)
DIM fcRise$(7)
DIM fcSet$(7)

currentCity$="London"
statusLine$=""
fetchOk%=FALSE

MODE 7
VDU 23,1,0;0;0;0;
PROCdraw_frame
PROCstatus("Initialising weather feed...")

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

DEF PROCrefresh_weather(city$)
LOCAL ok%
ok%=FALSE
fetchOk%=FALSE
PROCclear_forecast_arrays
PROCstatus("Looking up "+city$+"...")
PROCdraw_frame
PROCstatus("Looking up "+city$+"...")
IF FNlookup_location(city$)=FALSE THEN weatherDesc$="Location not found" : PROCshow_error(city$, "No matching location from Open-Meteo") : ENDPROC
PROCstatus("Fetching live weather for "+locName$+"...")
IF FNfetch_current_weather=FALSE THEN weatherDesc$="Current weather unavailable" : PROCshow_error(locName$, "Unable to read current conditions") : ENDPROC
IF FNfetch_forecast=FALSE THEN weatherDesc$="Forecast unavailable" : PROCshow_error(locName$, "Unable to read forecast data") : ENDPROC
weatherDesc$=FNweather_desc(VAL(weatherCode$))
fetchOk%=TRUE
PROCdraw_dashboard
PROCstatus("")
ENDPROC

DEF FNlookup_location(city$)
LOCAL h%, ok%, query$
ok%=FALSE
query$=FNurl_encode(city$)
url$="https://geocoding-api.open-meteo.com/v1/search?name="+query$+"&count=1&language=en&format=json"
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
=TRUE

DEF FNfetch_current_weather
IF FNfetch_current_segment1=FALSE THEN =FALSE
IF FNfetch_current_segment2=FALSE THEN =FALSE
IF FNfetch_current_segment3=FALSE THEN =FALSE
=TRUE

DEF FNfetch_current_segment1
LOCAL h%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&timezone=auto&current=relative_humidity_2m,weather_code,cloud_cover,surface_pressure"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
PROCjson_read(h%, "/current/time")
weatherTime$=jsonValue$
PROCjson_read(h%, "/timezone_abbreviation")
weatherZone$=jsonValue$
PROCjson_read(h%, "/current/surface_pressure")
weatherPressure$=jsonValue$
PROCjson_read(h%, "/current/relative_humidity_2m")
weatherHumidity$=jsonValue$
PROCjson_read(h%, "/current/weather_code")
weatherCode$=jsonValue$
PROCjson_read(h%, "/current/cloud_cover")
weatherClouds$=jsonValue$
CLOSE#h%
=TRUE

DEF FNfetch_current_segment2
LOCAL h%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&current=temperature_2m,apparent_temperature,wind_speed_10m,wind_direction_10m"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
PROCjson_read(h%, "/current/temperature_2m")
weatherTemp$=jsonValue$
PROCjson_read(h%, "/current/apparent_temperature")
weatherFeels$=jsonValue$
PROCjson_read(h%, "/current/wind_speed_10m")
weatherWind$=jsonValue$
PROCjson_read(h%, "/current/wind_direction_10m")
weatherWindDeg$=jsonValue$
CLOSE#h%
=TRUE

DEF FNfetch_current_segment3
LOCAL h%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&hourly=dew_point_2m,visibility&forecast_hours=1"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
PROCjson_read(h%, "/hourly/dew_point_2m/0")
weatherDew$=jsonValue$
PROCjson_read(h%, "/hourly/visibility/0")
weatherVis$=jsonValue$
CLOSE#h%
=TRUE

DEF FNfetch_forecast
IF FNfetch_forecast_segment1=FALSE THEN =FALSE
IF FNfetch_forecast_segment2=FALSE THEN =FALSE
IF FNfetch_forecast_segment3=FALSE THEN =FALSE
IF FNfetch_forecast_segment4=FALSE THEN =FALSE
weatherSunrise$=fcRise$(0)
weatherSunset$=fcSet$(0)
=TRUE

DEF FNfetch_forecast_segment1
LOCAL h%, i%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&timezone=auto&forecast_days=8&forecast_hours=1&daily=temperature_2m_max,temperature_2m_min"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
FOR i%=0 TO 7
  PROCjson_read(h%, "/daily/time/"+STR$(i%))
  fcDate$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/temperature_2m_max/"+STR$(i%))
  fcMax$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/temperature_2m_min/"+STR$(i%))
  fcMin$(i%)=jsonValue$
NEXT
CLOSE#h%
=TRUE

DEF FNfetch_forecast_segment2
LOCAL h%, i%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&timezone=auto&forecast_days=8&forecast_hours=1&daily=wind_speed_10m_max,wind_direction_10m_dominant"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
FOR i%=0 TO 7
  PROCjson_read(h%, "/daily/wind_speed_10m_max/"+STR$(i%))
  fcWind$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/wind_direction_10m_dominant/"+STR$(i%))
  fcWindDeg$(i%)=jsonValue$
NEXT
CLOSE#h%
=TRUE

DEF FNfetch_forecast_segment3
LOCAL h%, i%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&timezone=auto&forecast_days=8&forecast_hours=1&daily=precipitation_sum,uv_index_max"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
FOR i%=0 TO 7
  PROCjson_read(h%, "/daily/precipitation_sum/"+STR$(i%))
  fcRain$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/uv_index_max/"+STR$(i%))
  fcUv$(i%)=jsonValue$
NEXT
CLOSE#h%
=TRUE

DEF FNfetch_forecast_segment4
LOCAL h%, i%
url$="https://api.open-meteo.com/v1/forecast?latitude="+locLat$+"&longitude="+locLon$+"&timezone=auto&forecast_days=8&forecast_hours=1&daily=weather_code,sunrise,sunset"
h%=OPENIN(url$)
IF h%=0 THEN =FALSE
FOR i%=0 TO 7
  PROCjson_read(h%, "/daily/weather_code/"+STR$(i%))
  fcCode$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/sunrise/"+STR$(i%))
  fcRise$(i%)=jsonValue$
  PROCjson_read(h%, "/daily/sunset/"+STR$(i%))
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
PROCdraw_frame
PROCdraw_location_panel
PROCdraw_current_panel
PROCdraw_forecast_row(0,14)
PROCdraw_forecast_row(4,18)
ENDPROC

DEF PROCdraw_frame
LOCAL row%
CLS
PRINT TAB(0,0);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(173)+CHR$(174));CHR$(172);CHR$(189);
FOR row%=1 TO 22
  PRINT TAB(0,row%);CHR$(147);CHR$(238);CHR$(135);STRING$(35," ");CHR$(147);CHR$(189);
NEXT
PRINT TAB(0,23);CHR$(147);CHR$(238);STRING$(12,CHR$(172)+CHR$(188)+CHR$(236));CHR$(172);CHR$(189);
PRINT TAB(0,1);CHR$(147);CHR$(238);CHR$(133);" ";CHR$(157);CHR$(132);"   FUJINET WEATHER ";CHR$(134);"METEO      ";CHR$(156);CHR$(147);CHR$(189);
PRINT TAB(4,22);CHR$(132);"L";CHR$(135);" locn ";CHR$(132);"R";CHR$(135);" refresh ";CHR$(132);"Q";CHR$(135);" quit";
ENDPROC

DEF PROCdraw_location_panel
LOCAL place$
place$=locName$
IF LEN(locState$)>0 THEN place$=place$+", "+locState$
IF LEN(locCountry$)>0 THEN place$=place$+" ("+locCountry$+")"
PRINT TAB(2,2);CHR$(131);FNpad(place$,35);
PRINT TAB(2,3);CHR$(135);"Updated ";FNtime_only(weatherTime$);" ";weatherZone$;
PRINT TAB(2,4);CHR$(134);FNpad(weatherDesc$,20);CHR$(135);" ";FNpad(FNicon_label(VAL(weatherCode$)),10);
ENDPROC

DEF PROCdraw_current_panel
PROCdraw_big_icon(2,6,VAL(weatherCode$))
PRINT TAB(16,6);CHR$(131);"Now ";weatherTemp$;CHR$(135);"C";
PRINT TAB(16,7);CHR$(134);"Feels ";weatherFeels$;CHR$(135);"C";
PRINT TAB(16,8);CHR$(132);"Wind ";FNpad(weatherWind$,5);CHR$(135);" ";FNwind_dir(weatherWindDeg$);
PRINT TAB(16,9);CHR$(133);"Hum ";FNpad(weatherHumidity$,4);CHR$(135);" Cld ";FNcloud(weatherClouds$);
PRINT TAB(16,10);CHR$(130);"Pres ";FNpad(weatherPressure$,6);
PRINT TAB(16,11);CHR$(131);"Dew ";FNpad(weatherDew$,5);CHR$(135);" Vis ";FNvis(weatherVis$);
PRINT TAB(16,12);CHR$(134);"Sun ";FNtime_only(weatherSunrise$);CHR$(135);"-";FNtime_only(weatherSunset$);
PRINT TAB(2,13);CHR$(131);FNpad("8 DAY OUTLOOK",35);
ENDPROC

DEF PROCdraw_big_icon(col%, row%, code%)
LOCAL kind%
kind%=FNicon_kind(code%)
IF kind%=0 THEN PRINT TAB(col%,row%);CHR$(131);"  / | / "; : PRINT TAB(col%,row%+1);CHR$(131);" -- O --"; : PRINT TAB(col%,row%+2);CHR$(131);"  / | / "; : ENDPROC
IF kind%=1 THEN PRINT TAB(col%,row%);CHR$(135);"   .--.  "; : PRINT TAB(col%,row%+1);CHR$(135);".-(____)."; : PRINT TAB(col%,row%+2);CHR$(134);" '-.__.-'"; : ENDPROC
IF kind%=2 THEN PRINT TAB(col%,row%);CHR$(135);"   .--.  "; : PRINT TAB(col%,row%+1);CHR$(135);".-(____)."; : PRINT TAB(col%,row%+2);CHR$(132);" ' ' ' ' "; : ENDPROC
IF kind%=3 THEN PRINT TAB(col%,row%);CHR$(135);"   .--.  "; : PRINT TAB(col%,row%+1);CHR$(133);".-(____)."; : PRINT TAB(col%,row%+2);CHR$(131);"  / / /  "; : ENDPROC
IF kind%=4 THEN PRINT TAB(col%,row%);CHR$(135);"   .--.  "; : PRINT TAB(col%,row%+1);CHR$(135);".-(____)."; : PRINT TAB(col%,row%+2);CHR$(135);"  *  *   "; : ENDPROC
PRINT TAB(col%,row%);CHR$(134);" ~~~~~~~~";
PRINT TAB(col%,row%+1);CHR$(135);"  ~~~~~~ ";
PRINT TAB(col%,row%+2);CHR$(134);" ~~~~~~~~";
ENDPROC

DEF PROCdraw_forecast_row(start%, row%)
LOCAL idx%, x%, code%, label$
FOR idx%=0 TO 3
  x%=2+idx%*9
  PRINT TAB(x%,row%);CHR$(131);FNpad(FNshort_date(fcDate$(start%+idx%)),8);
  PRINT TAB(x%,row%+1);CHR$(135);FNpad(FNshort_icon(VAL(fcCode$(start%+idx%))),8);
  PRINT TAB(x%,row%+2);CHR$(134);FNpad(fcMax$(start%+idx%)+"/"+fcMin$(start%+idx%),8);
  PRINT TAB(x%,row%+3);CHR$(132);FNpad(FNforecast_metric(start%+idx%),8);
NEXT
ENDPROC

DEF PROCshow_error(city$, msg$)
PROCdraw_frame
PRINT TAB(2,4);CHR$(129);"Weather fetch failed";
PRINT TAB(2,7);CHR$(135);FNpad(city$,34);
PRINT TAB(2,9);CHR$(131);FNpad(msg$,34);
PRINT TAB(2,11);CHR$(134);"Use L for location or R to retry";
PRINT TAB(2,13);CHR$(135);"Try London, Glasgow, Reykjavik";
PROCstatus("L=location  R=retry")
ENDPROC

DEF PROCstatus(msg$)
PRINT TAB(2,5);CHR$(130);FNpad(msg$,35);
ENDPROC

DEF PROCclear_forecast_arrays
FOR I%=0 TO 7
  fcDate$(I%)=""
  fcMax$(I%)=""
  fcMin$(I%)=""
  fcWind$(I%)=""
  fcWindDeg$(I%)=""
  fcRain$(I%)=""
  fcUv$(I%)=""
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
  PRINT TAB(2,5);CHR$(131);FNpad("Location: "+inputBuf$+"_",35);
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

DEF FNvis(s$)
LOCAL km, out$
IF LEN(s$)=0 THEN ="--"
km=VAL(s$)/1000
out$=STR$(INT(km+0.5))
=FNtrim(out$)+"k"

DEF FNcloud(s$)
IF LEN(s$)=0 THEN ="--"
=FNtrim(s$)+"%"

DEF FNforecast_metric(idx%)
LOCAL rain$, wind$
rain$=fcRain$(idx%)
IF LEN(rain$)=0 THEN rain$="-"
wind$=FNwind_dir(fcWindDeg$(idx%))
=LEFT$(rain$+"m "+wind$,8)

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

DEF FNweather_desc(code%)
IF code%=0 THEN ="Clear sky"
IF code%=1 THEN ="Mostly clear"
IF code%=2 THEN ="Partly cloudy"
IF code%=3 THEN ="Overcast"
IF code%=45 OR code%=48 THEN ="Fog"
IF code%=51 OR code%=53 OR code%=55 THEN ="Drizzle"
IF code%=56 OR code%=57 THEN ="Freezing drizzle"
IF code%=61 OR code%=63 OR code%=65 THEN ="Rain"
IF code%=66 OR code%=67 THEN ="Freezing rain"
IF code%=71 OR code%=73 OR code%=75 OR code%=77 THEN ="Snow"
IF code%=80 OR code%=81 OR code%=82 THEN ="Showers"
IF code%=85 OR code%=86 THEN ="Snow showers"
IF code%=95 THEN ="Thunderstorm"
IF code%=96 OR code%=99 THEN ="Storm with hail"
="Conditions unknown"
