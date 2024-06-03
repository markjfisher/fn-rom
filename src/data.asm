.BootOptions
    EQUS    "L.!BOOT",13
    EQUS    "E.!BOOT",13

; The args to commands, can be combined by 2 nybbles, up to 15 strings here
.parametertable
    EQUS '<' OR &80,"source> <dest.>"   ; 1
    EQUS '<' OR &80,"afsp>"             ; 2
    EQUS '<' OR &80,"fsp>"              ; 3
    EQUS '(' OR &80,"<dir>)"            ; 4
    EQUS '<' OR &80,"drive>"            ; 5
    EQUS '(' OR &80,"<num>)"            ; 6
    EQUS '<' OR &80,"dos name>"         ; 7
    EQUS '(' OR &80,"<dos name>)"       ; 8
    EQUS '<' OR &80,"filter>"           ; 9
    EQUS '(' OR &80,"<drive>)"          ; A
    ; EQUS '(' OR &80,"<drive>)..."       ; 
    ; ... etc
    EQUB &FF