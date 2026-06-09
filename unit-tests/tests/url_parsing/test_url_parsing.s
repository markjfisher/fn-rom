.export _main
.export t_url_sentinel_accepts_exact
.export t_url_sentinel_accepts_exact_end
.export t_url_sentinel_rejects_extra
.export t_url_sentinel_rejects_extra_end
.export t_read_fspba_sets_url_flags
.export t_read_fspba_sets_url_flags_end

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
        rts

t_url_sentinel_accepts_exact:
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #':'
        sta     mock_cmdline+0
        lda     #'/'
        sta     mock_cmdline+1
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
        jsr     fs_check_open_url_sentinel
t_url_sentinel_accepts_exact_end:
        rts

t_url_sentinel_rejects_extra:
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #':'
        sta     mock_cmdline+0
        lda     #'/'
        sta     mock_cmdline+1
        sta     mock_cmdline+2
        lda     #'X'
        sta     mock_cmdline+3
        lda     #$00
        sta     mock_cmdline+4
        jsr     fs_check_open_url_sentinel
t_url_sentinel_rejects_extra_end:
        rts

t_read_fspba_sets_url_flags:
        lda     #$00
        sta     fuji_ext_str_flags
        sta     fuji_ext_str_len
        sta     fuji_ext_str_len_hi
        sta     fuji_network_url_flag
        lda     #'Q'
        sta     fuji_default_dir
        lda     #$02
        sta     fuji_default_drive
        lda     #<mock_cmdline
        sta     aws_tmp10
        lda     #>mock_cmdline
        sta     aws_tmp11
        lda     #'h'
        sta     mock_cmdline+0
        lda     #'o'
        sta     mock_cmdline+1
        lda     #'s'
        sta     mock_cmdline+2
        lda     #'t'
        sta     mock_cmdline+3
        lda     #':'
        sta     mock_cmdline+4
        lda     #'/'
        sta     mock_cmdline+5
        sta     mock_cmdline+6
        lda     #'f'
        sta     mock_cmdline+7
        lda     #'o'
        sta     mock_cmdline+8
        lda     #'o'
        sta     mock_cmdline+9
        lda     #$00
        sta     mock_cmdline+10
        jsr     call_read_fspba_reset
t_read_fspba_sets_url_flags_end:
        rts
