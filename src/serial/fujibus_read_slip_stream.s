; Serial raw-link implementation for FujiBus.
; Shared SLIP framing lives in fuji_link_slip.s.

        .export fuji_link_check_byte_available
        .export fuji_link_read_byte
        .export fuji_link_restore_default_io
        .export fuji_link_setup

        .import check_rs423_buffer
        .import read_rs423_char
        .import restore_output_to_screen
        .import setup_serial_19200

        .include "fujinet.inc"

        .segment "CODE"

fuji_link_setup:
        jmp     setup_serial_19200

fuji_link_restore_default_io:
        jmp     restore_output_to_screen

fuji_link_check_byte_available:
        jmp     check_rs423_buffer

fuji_link_read_byte:
        jmp     read_rs423_char
