; Command tables for FujiNet ROM
        .export cmd_table1, cmd_table1_size, cmd_table3, cmd_table3_size

        .segment "RODATA"

; COMMAND TABLE 1 - Main FujiNet commands
cmd_table1:
        .byte   $FF                ; Last command number (-1)
        
        .byte   "CLOSE", $80       ; No parameters
        .byte   "COPY", $80        ; No parameters (for now)
        .byte   "DELETE", $80      ; No parameters (for now)
        .byte   "DIR", $80         ; No parameters (for now)
        .byte   "DRIVE", $80       ; No parameters (for now)
        .byte   "INFO", $80        ; No parameters (for now)
        .byte   "LIB", $80         ; No parameters (for now)
        .byte   0                  ; End of table
cmd_table1_end:

; COMMAND TABLE 3 - Help commands (like MMFS cmdtable3)
cmd_table3:
        .byte   "FUTILS", $80
        .byte   0                  ; End of table
cmd_table3_end:

; Calculate table sizes
cmd_table1_size = (cmd_table1_end - cmd_table1) - 1  ; Subtract 1 for the $FF byte
cmd_table3_size = (cmd_table3_end - cmd_table3) - 1  ; Subtract 1 for the $00 terminator
