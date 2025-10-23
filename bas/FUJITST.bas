REM filename: FUJITST
REM FujiNet Serial Test
REM Tests serial communication via ACIA

REM Configure SERPROC for 19200 baud
?&FE10=&00:REM TX=19200,RX=19200,RS423=0,Motor=0

REM Configure ACIA
?&FE08=&03:REM Master reset
?&FE08=&15:REM 8N1,RTS low,TX int off,RX int on

REM Wait for ACIA ready to transmit
REPEAT:UNTIL (?&FE08 AND &02)<>0

REM Send test packet: 70 00 00 00 00 70
REM Device=70, Cmd=00 00 00 00, Checksum=70
PRINT "Sending test packet..."
?&FE09=&70:REM Device byte
?&FE09=&00:REM Command byte 1
?&FE09=&00:REM Command byte 2
?&FE09=&00:REM Command byte 3
?&FE09=&00:REM Command byte 4
?&FE09=&70:REM Checksum

PRINT "Packet sent. Waiting for response..."

REM Wait for response with timeout
timeout%=10000
FOR I%=1 TO timeout%
  IF (?&FE08 AND &01)<>0 THEN GOTO 100
NEXT I%
PRINT "No response received."
END

REM Read first response byte
100
byte%=?&FE09
PRINT "Response: ";~byte%;" ";

REM Continue reading response bytes
FOR I%=1 TO 100
  REM Check if byte available
  IF (?&FE08 AND &01)=0 THEN GOTO 200
  PRINT ~?&FE09;" ";
NEXT I%

200
PRINT
PRINT "Done."

