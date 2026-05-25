; Serial raw-link implementation for FujiBus.
; Shared SLIP framing lives in fuji_link_slip.s.
; RX currently uses MOS RS423 buffering, so callers must enter with IRQs
; enabled for the duration of receive.

        .export fuji_link_check_byte_available
        .export fuji_link_read_byte
        .export fuji_link_restore_default_io
        .export fuji_link_setup
        .export fuji_link_setup_write

        .import check_rs423_buffer
        .import read_rs423_char
        .import restore_output_to_screen
        .import setup_serial_19200
        .import setup_serial_19200_and_flush

        .include "fujinet.inc"

        .segment "CODE"

fuji_link_setup:
        jmp     setup_serial_19200

fuji_link_setup_write:
        jmp     setup_serial_19200_and_flush

fuji_link_restore_default_io:
        jmp     restore_output_to_screen

fuji_link_check_byte_available:
        jmp     check_rs423_buffer

fuji_link_read_byte:
        jmp     read_rs423_char
