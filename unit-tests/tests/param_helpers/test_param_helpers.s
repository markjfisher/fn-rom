.export _main
.export t_num_params_zero
.export t_num_params_zero_end
.export t_num_params_two
.export t_num_params_two_end
.export t_param_count_range01_lower
.export t_param_count_range01_lower_end
.export t_param_count_range01_upper
.export t_param_count_range01_upper_end
.export t_param_count_range12_lower
.export t_param_count_range12_lower_end
.export t_param_count_range12_upper
.export t_param_count_range12_upper_end
.export t_param_drive_default
.export t_param_drive_default_end
.export t_param_drive_explicit
.export t_param_drive_explicit_end
.export t_param_get_string_reads_text
.export t_param_get_string_reads_text_end
.export t_param_get_string_max_x_truncates
.export t_param_get_string_max_x_truncates_end
.export t_param_get_byte_0, t_param_get_byte_0_end
.export t_param_get_byte_9, t_param_get_byte_9_end
.export t_param_get_byte_10, t_param_get_byte_10_end
.export t_param_get_byte_69, t_param_get_byte_69_end
.export t_param_get_byte_255, t_param_get_byte_255_end
.export t_param_get_byte_all, t_param_get_byte_all_end
.export t_param_get_byte_rejects_text
.export t_param_get_byte_rejects_four_digits
.export t_param_get_byte_rejects_overflow
.export byte_results
.export param_error_block

.export result_carry
.export result_a

result_carry = $2220
result_a = $2221
byte_results = $2222
param_error_block = $0100

.import mock_cmdline

.include "fnrom.inc"

.code

capture_carry:
        php
        pla
        and     #$01
        sta     result_carry
        rts

capture_a_carry:
        sta     result_a
        php
        pla
        and     #$01
        sta     result_carry
        rts

_main:
        rts

set_cmd_ptr:
        lda     #<mock_cmdline
        sta     text_pointer+0
        lda     #>mock_cmdline
        sta     text_pointer+1
        rts

t_num_params_zero:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #$00
        sta     mock_cmdline+0
        jsr     num_params
t_num_params_zero_end:
        rts

t_num_params_two:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'7'
        sta     mock_cmdline+0
        lda     #' '
        sta     mock_cmdline+1
        lda     #'A'
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
        jsr     num_params
t_num_params_two_end:
        rts

t_param_count_range01_lower:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #$00
        sta     mock_cmdline+0
        lda     #$00
        jsr     param_count_a
        jsr     capture_carry
t_param_count_range01_lower_end:
        rts

t_param_count_range01_upper:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'7'
        sta     mock_cmdline+0
        lda     #$00
        sta     mock_cmdline+1
        lda     #$00
        jsr     param_count_a
        jsr     capture_carry
t_param_count_range01_upper_end:
        rts

t_param_count_range12_lower:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'7'
        sta     mock_cmdline+0
        lda     #$00
        sta     mock_cmdline+1
        lda     #$80
        jsr     param_count_a
        jsr     capture_carry
t_param_count_range12_lower_end:
        rts

t_param_count_range12_upper:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'7'
        sta     mock_cmdline+0
        lda     #' '
        sta     mock_cmdline+1
        lda     #'A'
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
        lda     #$80
        jsr     param_count_a
        jsr     capture_carry
t_param_count_range12_upper_end:
        rts

t_param_drive_default:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #$02
        sta     fuji_default_drive
        lda     #$00
        sta     mock_cmdline+0
        clc
        jsr     param_drive_or_default
t_param_drive_default_end:
        rts

t_param_drive_explicit:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #$01
        sta     fuji_default_drive
        lda     #'3'
        sta     mock_cmdline+0
        lda     #$00
        sta     mock_cmdline+1
        sec
        jsr     param_drive_or_default
t_param_drive_explicit_end:
        rts

t_param_get_string_reads_text:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'F'
        sta     mock_cmdline+0
        lda     #'O'
        sta     mock_cmdline+1
        lda     #'O'
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
        clc
        jsr     param_get_string
        jsr     capture_a_carry
t_param_get_string_reads_text_end:
        rts

t_param_get_string_max_x_truncates:
        jsr     set_cmd_ptr
        ldy     #$00
        lda     #'H'
        sta     mock_cmdline+0
        lda     #'E'
        sta     mock_cmdline+1
        lda     #'L'
        sta     mock_cmdline+2
        lda     #'L'
        sta     mock_cmdline+3
        lda     #'O'
        sta     mock_cmdline+4
        lda     #$00
        sta     mock_cmdline+5
        clc
        ldx     #$03
        jsr     param_get_string_max_x
        jsr     capture_a_carry
t_param_get_string_max_x_truncates_end:
        rts

.macro byte_case name, endname, text
name:
        jsr     set_cmd_ptr
        ldy     #0
        ldx     #0
@copy: lda     text,x
        sta     mock_cmdline,x
        inx
        cmp     #0
        bne     @copy
        jsr     param_get_byte
        sta     result_a
endname:
        rts
.endmacro

byte_case t_param_get_byte_0, t_param_get_byte_0_end, str_byte_0
byte_case t_param_get_byte_9, t_param_get_byte_9_end, str_byte_9
byte_case t_param_get_byte_10, t_param_get_byte_10_end, str_byte_10
byte_case t_param_get_byte_69, t_param_get_byte_69_end, str_byte_69
byte_case t_param_get_byte_255, t_param_get_byte_255_end, str_byte_255

.macro invalid_byte_case name, text
name:
        jsr     set_cmd_ptr
        ldy     #0
        ldx     #0
@copy: lda     text,x
        sta     mock_cmdline,x
        inx
        cmp     #0
        bne     @copy
        jmp     param_get_byte
.endmacro

invalid_byte_case t_param_get_byte_rejects_text, str_byte_text
invalid_byte_case t_param_get_byte_rejects_four_digits, str_byte_four_digits
invalid_byte_case t_param_get_byte_rejects_overflow, str_byte_overflow

t_param_get_byte_all:
        jsr t_param_get_byte_0
        lda result_a
        sta byte_results+0
        jsr t_param_get_byte_9
        lda result_a
        sta byte_results+1
        jsr t_param_get_byte_10
        lda result_a
        sta byte_results+2
        jsr t_param_get_byte_69
        lda result_a
        sta byte_results+3
        jsr t_param_get_byte_255
        lda result_a
        sta byte_results+4
t_param_get_byte_all_end:
        rts

.code
str_byte_0:   .byte "0",0
str_byte_9:   .byte "9",0
str_byte_10:  .byte "10",0
str_byte_69:  .byte "69",0
str_byte_255: .byte "255",0
str_byte_text: .byte "foo",0
str_byte_four_digits: .byte "1000",0
str_byte_overflow: .byte "256",0
