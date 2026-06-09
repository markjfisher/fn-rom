.export _main
.export t_empty_tail_uses_default_dir_and_drive0
.export t_empty_tail_uses_default_dir_and_drive0_end
.export t_directory_only_updates_dir
.export t_directory_only_updates_dir_end
.export t_drive_only_updates_drive
.export t_drive_only_updates_drive_end
.export t_drive_and_directory_update_both
.export t_drive_and_directory_update_both_end

.import mock_cmdline

.include "fnrom.inc"

.code

_main:
        rts

set_cmd_ptr:
        lda     #<mock_cmdline
        sta     text_pointer+0
        lda     #>mock_cmdline
        sta     text_pointer+1
        rts

t_empty_tail_uses_default_dir_and_drive0:
        jsr     set_cmd_ptr
        lda     #'Q'
        sta     fuji_default_dir
        lda     #'X'
        sta     directory_param
        lda     #$03
        sta     current_drv
        lda     #$00
        sta     mock_cmdline+0
        jsr     read_dir_drv_parameters
t_empty_tail_uses_default_dir_and_drive0_end:
        rts

t_directory_only_updates_dir:
        jsr     set_cmd_ptr
        lda     #'Q'
        sta     fuji_default_dir
        lda     #$02
        sta     fuji_default_drive
        lda     #'A'
        sta     mock_cmdline+0
        lda     #$00
        sta     mock_cmdline+1
        jsr     read_dir_drv_parameters
t_directory_only_updates_dir_end:
        rts

t_drive_only_updates_drive:
        jsr     set_cmd_ptr
        lda     #'Q'
        sta     fuji_default_dir
        sta     directory_param
        lda     #$01
        sta     fuji_default_drive
        lda     #':'
        sta     mock_cmdline+0
        lda     #'3'
        sta     mock_cmdline+1
        lda     #$00
        sta     mock_cmdline+2
        jsr     read_dir_drv_parameters2
t_drive_only_updates_drive_end:
        rts

t_drive_and_directory_update_both:
        jsr     set_cmd_ptr
        lda     #'Q'
        sta     fuji_default_dir
        sta     directory_param
        lda     #$01
        sta     fuji_default_drive
        lda     #':'
        sta     mock_cmdline+0
        lda     #'3'
        sta     mock_cmdline+1
        lda     #'.'
        sta     mock_cmdline+2
        lda     #'A'
        sta     mock_cmdline+3
        lda     #$00
        sta     mock_cmdline+4
        jsr     read_dir_drv_parameters2
t_drive_and_directory_update_both_end:
        rts
