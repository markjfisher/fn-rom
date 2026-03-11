; os.inc
;
; imports for the os constants

.ifndef OS_INC
OS_INC = 1

        .import  GSINIT
        .import  GSREAD
        .import  OSARGS
        .import  OSASCI
        .import  OSBGET
        .import  OSBPUT
        .import  OSBYTE
        .import  OSCLI
        .import  OSFILE
        .import  OSFIND
        .import  OSGBPB
        .import  OSNEWL
        .import  OSRDCH
        .import  OSRDRM
        .import  OSWORD
        .import  OSWRCH
        .import  ROMSEL

        .import  current_cat
        .import  dfs_cat_num_x8
        .import  FSCV
        .import  paged_rom_priv_ws

        .import  fuji_buf_ws_tmp_buf

        .import  fuji_static_workspace
        .import  fuji_filename_buffer
        .import  fuji_open_channels
        .import  fuji_channel_flag_bit
        .import  fuji_intch
        .import  fuji_cat_file_offset
        .import  fuji_channel_block_size
        .import  fuji_saved_x
        .import  fuji_fs_messages_on
        .import  fuji_cmd_enabled
        .import  fuji_default_dir
        .import  fuji_default_drive
        .import  fuji_lib_dir
        .import  fuji_lib_drive
        .import  fuji_wild_hash
        .import  fuji_wild_star
        .import  fuji_page
        .import  fuji_ram_buffer_size
        .import  fuji_source_drive
        .import  fuji_dest_drive
        .import  fuji_force_reset
        .import  fuji_disk_table_index
        .import  fuji_tube_present
        .import  fuji_text_ptr_offset
        .import  fuji_text_ptr_hi
        .import  fuji_param_block_lo
        .import  fuji_param_block_hi
        .import  fuji_error_flag

        .import  fuji_drive_disk_map
        .import  fuji_state
        .import  fuji_buffer_addr
        .import  fuji_file_offset
        .import  fuji_block_size
        .import  fuji_current_sector
        .import  fuji_current_fs_len
        .import  fuji_current_dir_len
        .import  fuji_current_mount_slot
        .import  fuji_resolve_path_flags
        .import  fuji_disk_slot
        .import  fuji_disk_flags
        .import  fuji_cmd_offset_y
        .import  fuji_filename_len

        .import  fuji_last_state_loc

        .import  fuji_channel_start

        .import  fuji_ch_1101
        .import  fuji_ch_1102
        .import  fuji_ch_1103
        .import  fuji_ch_1104
        .import  fuji_ch_1105
        .import  fuji_ch_1106
        .import  fuji_ch_1107
        .import  fuji_ch_1108
        .import  fuji_ch_1109
        .import  fuji_ch_110A
        .import  fuji_ch_110B

        .import  fuji_ch_name7
        .import  fuji_ch_op
        .import  fuji_ch_dir
        .import  fuji_ch_sec_start
        .import  fuji_ch_bitmask
        .import  fuji_ch_sect_lo
        .import  fuji_ch_sect_hi

        .import  fuji_ch_bptr_low
        .import  fuji_ch_bptr_mid
        .import  fuji_ch_bptr_hi
        .import  fuji_ch_buf_page
        .import  fuji_ch_ext_low
        .import  fuji_ch_ext_mid
        .import  fuji_ch_ext_hi
        .import  fuji_ch_flg

        .import  fuji_cmd_copy_buf_17
        .import  fuji_cmd_cat_buf_8
        .import  fuji_getcat_buf_8

        .import  fuji_buf_ws_tmp_buf

        .import  fuji_filev_hi_addr_buf
        .import  fuji_filev_load_hi
        .import  fuji_filev_exec_hi
        .import  fuji_filev_start_hi
        .import  fuji_filev_end_hi


        .import  fuji_ch_1118
        .import  fuji_ch_1119
        .import  fuji_ch_111A

        .import  fuji_unknown_11C0
        .import  fuji_unknown_11D0

        .import  _fuji_current_fs_uri
        .import  _fuji_current_dir_path
        .import  _fuji_tx_buffer
        .import  _fuji_rx_buffer
        .import  fuji_bss

        .import  dfs_cat_s0_header
        .import  dfs_cat_s1_header
        .import  dfs_cat_s0_title
        .import  dfs_cat_s1_title
        .import  dfs_cat_cycle
        .import  dfs_cat_num_x8
        .import  dfs_cat_boot_option
        .import  dfs_cat_sect_count
        .import  dfs_cat_file_s0_start
        .import  dfs_cat_file_name
        .import  dfs_cat_file_dir
        .import  dfs_cat_file_s1_start
        .import  dfs_cat_file_load_addr
        .import  dfs_cat_file_exec_addr
        .import  dfs_cat_file_size
        .import  dfs_cat_file_op
        .import  dfs_cat_file_sect


        .importzp  aws_tmp00
        .importzp  aws_tmp01
        .importzp  aws_tmp02
        .importzp  aws_tmp03
        .importzp  aws_tmp04
        .importzp  aws_tmp05
        .importzp  aws_tmp06
        .importzp  aws_tmp07
        .importzp  aws_tmp08
        .importzp  aws_tmp09
        .importzp  aws_tmp10
        .importzp  aws_tmp11
        .importzp  aws_tmp12
        .importzp  aws_tmp13
        .importzp  aws_tmp14
        .importzp  aws_tmp15
        .importzp  cws_tmp1
        .importzp  cws_tmp2
        .importzp  cws_tmp3
        .importzp  cws_tmp4
        .importzp  cws_tmp5
        .importzp  cws_tmp6
        .importzp  cws_tmp7
        .importzp  cws_tmp8
        .importzp  pws_tmp00
        .importzp  pws_tmp01
        .importzp  pws_tmp02
        .importzp  pws_tmp03
        .importzp  pws_tmp04
        .importzp  pws_tmp05
        .importzp  pws_tmp06
        .importzp  pws_tmp07
        .importzp  pws_tmp08
        .importzp  pws_tmp09
        .importzp  pws_tmp10
        .importzp  pws_tmp11
        .importzp  pws_tmp12
        .importzp  pws_tmp13
        .importzp  pws_tmp14
        .importzp  pws_tmp15

        .importzp  current_drv
        .importzp  directory_param
        .importzp  paged_ram_copy
        .importzp  text_pointer

.endif
