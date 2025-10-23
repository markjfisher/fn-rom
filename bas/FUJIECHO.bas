REM filename: FUJIECHO
REM FujiNet Serial Echo Test
REM Sends a string and echoes responses

REM Configure serial hardware
PROC_init_serial

REM Main loop
REPEAT
  PRINT "Enter command (or QUIT): ";
  INPUT cmd$
  IF cmd$="QUIT" THEN END
  
  REM Send command as packet
  PROC_send_packet(cmd$)
  
  REM Read and display response
  PROC_read_response
UNTIL FALSE
END

REM Initialize serial hardware
DEF PROC_init_serial
  REM SERPROC: 19200 baud
  ?&FE10=&00
  REM ACIA: Master reset
  ?&FE08=&03
  REM ACIA: 8N1, RTS low
  ?&FE08=&15
ENDPROC

REM Send packet with checksum
DEF PROC_send_packet(data$)
  LOCAL I%,chk%
  REM Wait for ACIA ready
  REPEAT:UNTIL (?&FE08 AND &02)<>0
  
  REM Device byte
  ?&FE09=&70
  chk%=&70
  
  REM Send data bytes (max 5)
  FOR I%=1 TO LEN(data$)
    IF I%>5 THEN I%=6:GOTO 100
    ?&FE09=ASC(MID$(data$,I%,1))
    chk%=(chk%+ASC(MID$(data$,I%,1))) AND &FF
  NEXT I%
  100
  
  REM Pad with zeros if needed
  FOR I%=LEN(data$)+1 TO 5
    ?&FE09=0
  NEXT I%
  
  REM Send checksum
  ?&FE09=chk%
  
  PRINT "Sent: ";data$
ENDPROC

REM Read response from serial
DEF PROC_read_response
  LOCAL I%,byte%,timeout%
  PRINT "Response: ";
  
  REM Wait for first byte (with timeout)
  timeout%=5000
  FOR I%=1 TO timeout%
    IF (?&FE08 AND &01)<>0 THEN GOTO 200
  NEXT I%
  PRINT "(timeout)"
  ENDPROC
  200
  
  REM Read available bytes
  FOR I%=1 TO 64
    IF (?&FE08 AND &01)=0 THEN GOTO 300
    byte%=?&FE09
    IF byte%>=32 AND byte%<127 THEN PRINT CHR$(byte%);ELSE PRINT "[";~byte%;"]";
  NEXT I%
  300
  PRINT
ENDPROC

