; OSFILE operation 0 - Save memory block
; Handles memory block saving operations
; Translated from MMFS mmfs100.asm lines 2028-2045

        .export osfile0_savememblock
        .export SaveMemBlock

        .import create_file_fsp
        .import set_param_block_pointer_b0
        .import read_file_attribs_to_b0_yoffset
        .import fuji_execute_block_rw

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; osfile0_savememblock - Save memory block (A=0)
; Translated from MMFS lines 2028-2045
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

osfile0_savememblock:
        jsr     create_file_fsp
        jsr     set_param_block_pointer_b0
        jsr     read_file_attribs_to_b0_yoffset
        ; fall into SaveMemBlock

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SaveMemBlock - Save block of memory
; FujiNet equivalent - use network write operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SaveMemBlock:
        lda     #$A5                     ; Write operation
        jsr     fuji_execute_block_rw
        rts
