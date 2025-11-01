REM filename: FRESET
REM FujiNet Reset Command via Serial Port
REM Mimics test-serial/test.c Reset Command (option 1)

DIM asmOSBYTE 12
DIM asmOSWRCH 8
DIM packet 7
OSBYTE=&FFF4
OSWRCH=&FFEE

REM Assemble machine code routines
PROCasmInit

REM FujiNet device IDs
THE_FUJI=&70

REM Main program
PRINT "FujiNet Reset Command"
PRINT "====================="
PRINT

REM Execute the reset
PROCfn_reset

PRINT "Reset command sent successfully"
PRINT "FujiNet should now be reset"

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

DEF PROCfn_reset
REM Setup serial ports for 19200 baud
PROCsetup_serial_ports

REM Send reset command (0xFF) with 4 zero arguments to THE_FUJI (0x70)
PROCsend_data_to_device(THE_FUJI, &FF, 0, 0, 0, 0)

REM Reset everything back to screen/keyboard
PROCreset_serial_to_screen
ENDPROC