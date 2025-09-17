; Service call 09 - Help
        .export service09_help
        .import print_string, print_newline, print_char, cmd_table3, cmd_table3_size
        .import remember_axy, rom_title, rom_version_string

        .segment "CODE"

service09_help:
        jsr     remember_axy       ; Preserve A, X, Y
        
        ; Check if this is just *HELP (no arguments)
        ; TextPointer is at $F2, Y contains offset to first non-space char
        lda     ($F2),y             ; Get character at (TextPointer)+Y
        cmp     #13                 ; CHR$(13) = carriage return
        bne     check_command       ; If not CR, check for command
        
        ; Just *HELP - print basic help (like MMFS Prthelp_Xtable)
        jsr     print_basic_help
        rts

check_command:
        ; TODO: Implement command parsing for *HELP <command>
        ; For now, just print basic help
        jsr     print_basic_help
        rts

print_basic_help:
        ; Print newline first
        lda     #13
        jsr     print_char
        
        ; Print system name and version
        lda     #<rom_title
        ldx     #>rom_title
        jsr     print_string
        
        ; Print space
        lda     #32
        jsr     print_char
        
        ; Print version (skip the 0 byte by adding 1 to location)
        lda     #<(rom_version_string + 1)
        ldx     #>(rom_version_string + 1)
        jsr     print_string
        
        ; Print newline
        lda     #13
        jsr     print_char
        
        ; Print available commands from table with proper indentation
        ; ... fall through

print_help_commands:
        ; Print help commands from cmd_table3 (like MMFS help_dfs_loop)
        lda     #<cmd_table3
        sta     $AE
        lda     #>cmd_table3
        sta     $AF
        ldy     #0
        
print_cmd_loop:
        lda     ($AE),y
        beq     print_cmd_done       ; End of table
        
        ; Print 2 spaces for indentation
        lda     #32
        jsr     print_char
        lda     #32
        jsr     print_char
        
        ; Print command name
print_cmd_name_loop:
        lda     ($AE),y
        cmp     #$80                 ; Check for command code terminator
        beq     print_cmd_name_done
        jsr     print_char
        iny
        bne     print_cmd_name_loop
print_cmd_name_done:
        
        ; Skip command code byte
        iny
        ; Print newline
        jsr     print_newline
        
        ; Continue to next command
        jmp     print_cmd_loop
        
print_cmd_done:
        rts

