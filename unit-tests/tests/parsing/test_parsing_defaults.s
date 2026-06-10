.export _main
.export t_default_drive
.export t_default_drive_end
.export t_explicit_drive
.export t_explicit_drive_end
.export t_bare_filename
.export t_bare_filename_end
.export t_drive_prefix
.export t_drive_prefix_end
.export t_dir_prefix
.export t_dir_prefix_end

.import init_harness
.import mock_cmdline

.include "fnrom.inc"

.code

call_read_fspba_reset:
        lda     #>(@ret - 1)
        pha
        lda     #<(@ret - 1)
        pha
        jmp     read_fspba_reset
@ret:
        rts

_main:
        lda     #$02
        sta     fuji_default_drive
        lda     #$00
        sta     mock_cmdline
t_default_drive:
        ldy     #$00
        jsr     param_optional_drive_no
t_default_drive_end:

        lda     #$01
        sta     fuji_default_drive
        lda     #':'
        sta     mock_cmdline+0
        lda     #'3'
        sta     mock_cmdline+1
        lda     #$00
        sta     mock_cmdline+2
t_explicit_drive:
        ldy     #$00
        jsr     param_optional_drive_no
t_explicit_drive_end:

        lda     #$02
        sta     fuji_default_drive
        lda     #'Q'
        sta     fuji_default_dir
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #'F'
        sta     mock_cmdline+0
        lda     #'L'
        sta     mock_cmdline+1
        lda     #'S'
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
t_bare_filename:
        ldy     #$00
        jsr     call_read_fspba_reset
t_bare_filename_end:

        lda     #$01
        sta     fuji_default_drive
        lda     #'Q'
        sta     fuji_default_dir
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #':'
        sta     mock_cmdline+0
        lda     #'3'
        sta     mock_cmdline+1
        lda     #'.'
        sta     mock_cmdline+2
        lda     #'F'
        sta     mock_cmdline+3
        lda     #'L'
        sta     mock_cmdline+4
        lda     #'S'
        sta     mock_cmdline+5
        lda     #$00
        sta     mock_cmdline+6
t_drive_prefix:
        ldy     #$00
        jsr     call_read_fspba_reset
t_drive_prefix_end:

        lda     #$02
        sta     fuji_default_drive
        lda     #'$'
        sta     fuji_default_dir
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #'A'
        sta     mock_cmdline+0
        lda     #'.'
        sta     mock_cmdline+1
        lda     #'F'
        sta     mock_cmdline+2
        lda     #'L'
        sta     mock_cmdline+3
        lda     #'S'
        sta     mock_cmdline+4
        lda     #$00
        sta     mock_cmdline+5
t_dir_prefix:
        ldy     #$00
        jsr     call_read_fspba_reset
t_dir_prefix_end:
        rts
