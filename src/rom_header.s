; FujiNet ROM for BBC Micro
; Main ROM header
        .export rom_header, rom_title, rom_version_string

        .import handle_service

        .segment "HEADER"

rom_header:
        ; not a language
        .byte   $00, $00, $00

        jmp     handle_service          ; service entry

        .byte   $82                     ; rom type: service ROM, 6502 code
        .byte   <(rom_copyright)        ; (c) location
        .byte   $01                     ; version

rom_title:
        .byte   "FujiNet"

rom_version_string:
        .byte   0, "0.01"

rom_copyright:
        .byte   0, "(C) Mark Fisher 2025", 0
