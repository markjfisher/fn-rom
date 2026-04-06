REM filename: double
REM Attempt to do double buffering in mode 7 - doesn't seem to be working

MODE 7
REM Lower HIMEM to protect the second buffer at &7800-&7BFF
HIMEM = &7800

DIM asmSwap 40

REM Zero Page address to hold the target buffer high byte
ZP_HB = &70

REM Define hardware addresses
CRTC_ADDR = &FE00
CRTC_DATA = &FE01
OSBYTE    = &FFF4

PROCasmInit

REM Main Loop: Alternate buffers
REPEAT
  REM Switch to Buffer 2 (&7800)
  ?ZP_HB = &3C
  CALL flip_screen
  PRINT "DISPLAYING BUFFER 2 (&7800)"
  TIME = 0: REPEAT UNTIL TIME > 100 : REM Wait 1 second
  
  REM Switch to Buffer 1 (&7C00)
  ?ZP_HB = &3E
  CALL flip_screen
  PRINT "DISPLAYING BUFFER 1 (&7C00)"
  TIME = 0: REPEAT UNTIL TIME > 100 : REM Wait 1 second
UNTIL FALSE

DEF PROCasmInit
FOR I%=0 TO 2 STEP 2:P%=asmSwap
[ OPT I%
.flip_screen
  LDA #&13       \ OSBYTE 19 - Wait for VSync
  JSR OSBYTE     \ Call OS
  
  LDA #12        \ Select CRTC R12 (High byte)
  STA CRTC_ADDR
  LDA ZP_HB      \ Get target high byte from Zero Page
  STA CRTC_DATA
  
  LDA #13        \ Select CRTC R13 (Low byte)
  STA CRTC_ADDR
  LDA #0         \ MODE 7 buffers are always on 256-byte boundaries
  STA CRTC_DATA
  RTS
]
NEXT I%
ENDPROC
