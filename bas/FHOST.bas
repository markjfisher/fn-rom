REM filename: FHOST
REM FujiNet Get Hosts Command via Serial Port

DIM asmOSBYTE 25
DIM asmOSWRCH 8
DIM asmReadChar 30
DIM packet 7
OSBYTE=&FFF4
OSWRCH=&FFEE

REM Assemble machine code routines
PROCasmInit

REM FujiNet device IDs
THE_FUJI=&70

REM Main program
PRINT "FujiNet Get Hosts Command"
PRINT "========================="
PRINT

REM Execute the command
PROCfn_gethosts
RR$="going..."
PRINT RR$
RR$=FNread_response
PRINT "Response: ";RR$

PRINT "Should have hosts"

END

REM ============================================
REM PROCEDURE AND FUNCTION DEFINITIONS
REM ============================================

DEF PROCasmInit
REM Assemble OSBYTE wrapper
FOR I%=0 TO 2 STEP 2:P%=asmOSBYTE
  [OPT I%
   LDA &70
   LDX &71
   LDY &72
   JSR OSBYTE
   \ Store A,X,Y back in &70, &71, &72
   STA &70
   STX &71
   STY &72
   RTS
  ]
NEXT I%

REM Assemble OSWRCH wrapper
FOR I%=0 TO 2 STEP 2:P%=asmOSWRCH
  [OPT I%
   LDA &70
   JSR OSWRCH
   RTS
  ]
NEXT I%
ENDPROC

REM Assemble asmReadChar wrapper
FOR I%=0 TO 2 STEP 2:P%=asmReadChar
  [OPT I%
   LDA #&91
   LDX #&01
   LDY #&00
   JSR OSBYTE
   BCS no_char

   STY &70      \ Number of characters was in Y, store it in &70
   LDX #&01
   BNE exit

   .no_char
   LDX #&00
   STX &70      \ also set count to 0

   .exit
   STX &71      \ Store the exit code in &71
   RTS
  ]
NEXT I%

DEF PROCcallOSBYTE(op, r1, r2)
?&70=op
?&71=r1
?&72=r2
CALL asmOSBYTE
ENDPROC

DEF PROCcallOSWRCH(c)
?&70=c
CALL asmOSWRCH
ENDPROC

DEF FNcallReadChar
REM bytes read in &70, exit code in &71 where 1 is success. We return exit status, and leave byte in &70
CALL asmReadChar
=?&71

DEF PROCsetup_serial_ports
REM *fx 7,8 - Set RX to 19200 baud (BAUD_19200 = 8)
PROCcallOSBYTE(7, 8, 0)

REM *fx 8,8 - Set TX to 19200 baud (BAUD_19200 = 8)
PROCcallOSBYTE(8, 8, 0)

REM *fx 3,3 - Output data to serial port only (OUTPUT_SERIAL_ONLY = 3)
PROCcallOSBYTE(3, 3, 0)

REM *fx 2,1 - Input from serial port only (INPUT_SERIAL_ONLY = 1)
PROCcallOSBYTE(2, 1, 0)

REM *fx 21,0 - Flush keyboard buffer (FLUSH_KEYBOARD_BUFFER = 0)
PROCcallOSBYTE(21, 0, 0)

REM *fx 21,1 - Flush RS423 serial input buffer (FLUSH_SERIAL_INPUT_BUFFER = 1)
PROCcallOSBYTE(21, 1, 0)
ENDPROC

DEF PROCreset_serial_to_screen
REM *fx 3,0 - Reset screen output only (OUTPUT_SCREEN_ONLY = 0)
PROCcallOSBYTE(3, 0, 0)

REM *fx 2,0 - Reset keyboard input only (INPUT_KEYBOARD_ONLY = 0)
PROCcallOSBYTE(2, 0, 0)
ENDPROC

DEF FNrs232_checksum(buf, len)
LOCAL chk, i
chk=0
FOR i=0 TO len-1
  chk=((chk + buf?i) DIV 256) + ((chk + buf?i) AND 255)
NEXT i
=chk AND 255

DEF PROCsend_data_to_device(device_id, command, arg1, arg2, arg3, arg4)
LOCAL checksum, i

REM Build packet: device_id, command, arg1, arg2, arg3, arg4, checksum
packet?0=device_id
packet?1=command
packet?2=arg1
packet?3=arg2
packet?4=arg3
packet?5=arg4

REM Calculate checksum for first 6 bytes
checksum=FNrs232_checksum(packet, 6)
packet?6=checksum

REM Send the 7-byte packet via OSWRCH
FOR i=0 TO 6
  PROCcallOSWRCH(packet?i)
NEXT i
ENDPROC

DEF PROCfn_gethosts
REM Setup serial ports for 19200 baud
PROCsetup_serial_ports
REM Send Get Hosts command (0xF4) with 4 zero arguments to THE_FUJI (0x70)
PROCsend_data_to_device(THE_FUJI, &F4, 0, 0, 0, 0)
REM Reset everything back to screen/keyboard
PROCreset_serial_to_screen
ENDPROC

REM Read response from serial - This goes directly on the &FE0X locations
DEF FNread_response
  LOCAL A$,result%,I%,byte%,bytes_read%,bytes_waiting%,status%,attempts%
  A$=""
  bytes_read%=0
  attempts%=0
  REPEAT
    bytes_waiting%=FNcheck_rs423_buffer
`    PRINT "bytes waiting: "; bytes_waiting%
    IF bytes_waiting%=0 THEN attempts%=attempts%+1:GOTO 200
    attempts%=0
    FOR I%=1 TO bytes_waiting%
      status%=FNcallReadChar
      IF status%=0 THEN PRINT "Failed to read char": GOTO 450
      byte%=?&70
      IF byte%>=32 AND byte%<127 THEN A$=A$+CHR$(byte%) ELSE A$=A$+"."
    NEXT I%
    200 REM keep looping
  UNTIL bytes_read%>=10 OR attempts%>100
  IF attempts%>100 THEN PRINT "Max attempts reached"
450 REM exiting
=A$

REM Small timeout loop waiting for serial bytes. Returns 0 for timeout, or the count of available bytes
DEF FNwait_serial
  LOCAL timeout%,I%,count%,result%
  result%=0
  timeout%=1000
  FOR I%=1 TO timeout%
    count%=FNcallReadChar
    IF count%>0 THEN result%=count%: GOTO 500
  NEXT I%
500 REM exiting
=result%


DEF FNcheck_rs423_buffer
PROCcallOSBYTE(&80, &FE, &FF)
REM return the X value for number of bytes available
=?&71
