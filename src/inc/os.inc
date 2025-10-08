; os.inc
;
; imports for the os constants

.ifndef MOS_INC
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

        .import  CHECK_CRC7
        .import  CurrentCat
        .import  FilesX8
        .import  FSCV
        .import  MMC_CIDCRC
        .import  MMC_STATE
        .import  OWCtlBlock
        .import  paged_rom_priv_ws
        .import  VID
        .import  VID2

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
        .import  fuji_gbpb_table_lo
        .import  fuji_gbpb_table_hi
        .import  fuji_text_ptr_offset
        .import  fuji_text_ptr_hi
        .import  fuji_param_block_lo
        .import  fuji_param_block_hi
        .import  fuji_error_flag
        .import  fuji_card_sort

        .import  fuji_channel_flags
        .import  fuji_ch_bptr_low
        .import  fuji_ch_bptr_mid
        .import  fuji_ch_bptr_hi
        .import  fuji_ch_buf_page
        .import  fuji_ch_ext_low
        .import  fuji_ch_ext_mid
        .import  fuji_ch_ext_hi
        .import  fuji_ch_flg

        .import  fuji_state
        .import  fuji_current_disk
        .import  fuji_operation_type
        .import  fuji_buffer_addr
        .import  fuji_file_offset
        .import  fuji_block_size
        .import  fuji_current_sector

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

        .importzp  CurrentDrv
        .importzp  DirectoryParam
        .importzp  paged_ram_copy
        .importzp  TextPointer

.endif
