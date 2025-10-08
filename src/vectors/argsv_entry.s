; ARGSV_ENTRY - Arguments Vector
; Handles OSARGS calls for file argument operations
; Translated from MMFS mmfs100.asm lines 4939-4967

        .export argsv_entry

        .import print_axy
        .import print_string
        .import remember_axy
        .import return_with_a0

        .include "fujinet.inc"

        .segment "CODE"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ARGSV_ENTRY - Arguments Vector
; Handles OSARGS calls
; A = action to be taken
; X points to 4 byte area in Zero Page (always i/o processor)
; Y = file handle provided by OSFIND or 0
; Exit:
; X and Y are unchanged
; see 16.1.2 of New Advanced User Guide
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

argsv_entry:
        dbg_string_axy "ARGSV: "
        ; rts

        jsr     remember_axy
        cmp     #$FF
        beq     @channel_buffer_to_disk_yhandle_a0  ; If file(s) to media
        cpy     #$00
        beq     @argsv_y0
        cmp     #$04
        bcs     @argsv_exit              ; If A>=4
        jsr     return_with_a0
        cmp     #$03
        beq     @argsv3
        cmp     #$01
        bne     @argsv_rdseqptr_or_filelen
        jmp     @argsv_write_seq_pointer

@argsv_y0:
        cmp     #$02                    ; If A>=2
        bcs     @argsv_exit
        jsr     return_with_a0
        beq     @argsv_filesysnumber     ; If A=0
        lda     #$FF
        sta     $02,x                   ; 4 byte address of
        sta     $03,x                   ; "rest of command line"
        lda     fuji_text_ptr_offset   ; (see *run code)
        sta     $00,x
        lda     fuji_text_ptr_hi
        sta     $01,x
@argsv_exit:
        rts

@channel_buffer_to_disk_yhandle_a0:
        jsr     return_with_a0
@channel_buffer_to_disk_yhandle:
        ; TODO: Implement channel buffer to disk
        rts

@argsv_filesysnumber:
        ; Return filing system number
        lda     #filesysno
        sta     $00,x
        lda     #$00
        sta     $01,x
        sta     $02,x
        sta     $03,x
        rts

@argsv3:
        ; TODO: Implement ARGS operation 3
        rts

@argsv_rdseqptr_or_filelen:
        ; TODO: Implement read sequence pointer or file length
        rts

@argsv_write_seq_pointer:
        ; TODO: Implement write sequence pointer
        rts
