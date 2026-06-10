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

.export result_carry
.export result_a

result_carry = $2220
result_a = $2221

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
