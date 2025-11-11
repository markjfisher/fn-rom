        .export  _write_serial_data

        .import  inc_word_aws_tmp00_dec_word_aws_tmp02
        .import  restore_output_to_screen
        .import  setup_serial_19200

        .include "fujinet.inc"

; INPUT:
;  aws_tmp00/01 = buffer to data
;  asw_tmp02/03 = length

_write_serial_data:
        jsr     setup_serial_19200

        ldy     #$00
@loop:
        lda     (aws_tmp00), y
        jsr     OSWRCH                  ; preserves A,X,Y

        jsr     inc_word_aws_tmp00_dec_word_aws_tmp02      ; does not affect Y
        bne     @loop

        jmp     restore_output_to_screen
