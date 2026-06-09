.export _main
.export t_unmounted_current_detected
.export t_unmounted_current_detected_end
.export t_mounted_current_preserved
.export t_mounted_current_preserved_end
.export t_apply_library_drive_state
.export t_apply_library_drive_state_end

.export result_a
.export result_drive
.export result_dir

result_a = $2210
result_drive = $2211
result_dir = $2212

.import init_harness
.import mock_cmdline

.include "fnrom.inc"

.code

capture_state:
        sta     result_a
        lda     current_drv
        sta     result_drive
        lda     directory_param
        sta     result_dir
        rts

setup_exec_entry0_fls_q:
        lda     #'F'
        sta     dfs_cat_file_name+0
        lda     #'L'
        sta     dfs_cat_file_name+1
        lda     #'S'
        sta     dfs_cat_file_name+2
        lda     #' '
        sta     dfs_cat_file_name+3
        sta     dfs_cat_file_name+4
        sta     dfs_cat_file_name+5
        sta     dfs_cat_file_name+6
        lda     #'Q'
        sta     dfs_cat_file_dir+0
        lda     #$C0
        sta     dfs_cat_msbits+0
        lda     #$FF
        sta     dfs_cat_file_exec_addr+0
        sta     dfs_cat_file_exec_addr+1
        rts

setup_common_cmdline_fls:
        lda     #<mock_cmdline
        sta     text_pointer+0
        lda     #>mock_cmdline
        sta     text_pointer+1
        lda     #'F'
        sta     mock_cmdline+0
        lda     #'L'
        sta     mock_cmdline+1
        lda     #'S'
        sta     mock_cmdline+2
        lda     #$00
        sta     mock_cmdline+3
        lda     #'*'
        sta     fuji_wild_star
        lda     #'#'
        sta     fuji_wild_hash
        lda     #'Q'
        sta     fuji_default_dir
        sta     fuji_lib_dir
        rts

_main:
        rts

t_unmounted_current_detected:
        lda     #$00
        sta     current_drv
        lda     #$FF
        sta     fuji_drive_disk_map+0
        jsr     cmd_run_current_drive_map
        jsr     capture_state
t_unmounted_current_detected_end:
        rts

t_mounted_current_preserved:
        lda     #$00
        sta     current_drv
        lda     #$07
        sta     fuji_drive_disk_map+0
        jsr     cmd_run_current_drive_map
        jsr     capture_state
t_mounted_current_preserved_end:
        rts

t_apply_library_drive_state:
        lda     #$00
        sta     current_drv
        lda     #$03
        sta     fuji_lib_drive
        lda     #'Q'
        sta     fuji_lib_dir
        jsr     cmd_run_apply_library_drive
        jsr     capture_state
t_apply_library_drive_state_end:
        rts
