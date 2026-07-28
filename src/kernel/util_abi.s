; Stable ABI used by FN-BOOT transient utilities.
;
; Disk-loaded utilities must not call moving resident ROM labels directly.
; Each slot here is a fixed-address JMP veneer. A utility can JSR/JMP to the
; slot address and the resident ROM can move the real implementation later.

        .export fuji_util_abi_start
        .export fuji_util_abi_end
        .export fuji_util_abi_signature

        .import GSINIT_A
        .import GSREAD_A
        .import a_rorx4and3
        .import check_file_not_locked_or_open_y
        .import check_file_not_open_y
        .import check_for_disk_change
        .import copy_aws_tmp00_to_aws_tmp02_a
        .import create_file_3
        .import delete_cat_entry_adjust_ptr
        .import err_bad
        .import err_bad_drive
        .import err_no_host
        .import err_syntax
        .import exit_user_ok
        .import fhost_copy_and_resolve
        .import fhost_show_current
        .import fuji_clear_slot
        .import fuji_create_disk
        .import fuji_fs_uri_ptr
        .import fuji_get_slot
        .import fuji_restore_boot_disk
        .import fuji_set_disk_slot_from_mapping_or_error
        .import fuji_unmount_disk
        .import fujibus_receive_packet
        .import fujibus_send_packet
        .import fujibus_set_payload_buffer_ptr
        .import get_cat_entry
        .import get_cat_firstentry80
        .import get_cat_nextentry
        .import get_fuji_fs_uri_addr_to_aws_tmp00
        .import load_cur_drv_cat2
        .import load_mem_block
        .import num_params
        .import osbyte_0f_flush_inbuf2
        .import param_count
        .import param_drive_no_syntax
        .import param_get_num
        .import param_get_string
        .import param_optional_drive_no
        .import param_syntax_error_if_null
        .import parameter_afsp
        .import parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
        .import parameter_fsp
        .import print_bcd_spl
        .import print_char
        .import print_hex
        .import print_hex_spl
        .import print_newline
        .import print_nibble_spl
        .import print_string
        .import print_string_spl
        .import prt_filename_yoffset
        .import prt_info_msg_yoffset
        .import read_fsp_text_pointer
        .import report_error
        .import report_error_cb
        .import save_cat_to_disk
        .import save_mem_block
        .import set_curdrv_to_default
        .import set_load_addr_to_host
        .import y_add8
        .import y_sub8

        .segment "UTILABI"

fuji_util_abi_start:
fuji_util_abi_GSINIT_A:
        jmp     GSINIT_A
fuji_util_abi_GSREAD_A:
        jmp     GSREAD_A
fuji_util_abi_a_rorx4and3:
        jmp     a_rorx4and3
fuji_util_abi_check_file_not_locked_or_open_y:
        jmp     check_file_not_locked_or_open_y
fuji_util_abi_check_file_not_open_y:
        jmp     check_file_not_open_y
fuji_util_abi_check_for_disk_change:
        jmp     check_for_disk_change
fuji_util_abi_copy_aws_tmp00_to_aws_tmp02_a:
        jmp     copy_aws_tmp00_to_aws_tmp02_a
fuji_util_abi_create_file_3:
        jmp     create_file_3
fuji_util_abi_delete_cat_entry_adjust_ptr:
        jmp     delete_cat_entry_adjust_ptr
fuji_util_abi_err_bad:
        jmp     err_bad
fuji_util_abi_err_bad_drive:
        jmp     err_bad_drive
fuji_util_abi_err_no_host:
        jmp     err_no_host
fuji_util_abi_err_syntax:
        jmp     err_syntax
fuji_util_abi_exit_user_ok:
        jmp     exit_user_ok
fuji_util_abi_fhost_copy_and_resolve:
        jmp     fhost_copy_and_resolve
fuji_util_abi_fhost_show_current:
        jmp     fhost_show_current
fuji_util_abi_fuji_clear_slot:
        jmp     fuji_clear_slot
fuji_util_abi_fuji_create_disk:
        jmp     fuji_create_disk
fuji_util_abi_fuji_fs_uri_ptr:
        jmp     fuji_fs_uri_ptr
fuji_util_abi_fuji_get_slot:
        jmp     fuji_get_slot
fuji_util_abi_fuji_restore_boot_disk:
        jmp     fuji_restore_boot_disk
fuji_util_abi_fuji_set_disk_slot_from_mapping_or_error:
        jmp     fuji_set_disk_slot_from_mapping_or_error
fuji_util_abi_fuji_unmount_disk:
        jmp     fuji_unmount_disk
fuji_util_abi_fujibus_receive_packet:
        jmp     fujibus_receive_packet
fuji_util_abi_fujibus_send_packet:
        jmp     fujibus_send_packet
fuji_util_abi_fujibus_set_payload_buffer_ptr:
        jmp     fujibus_set_payload_buffer_ptr
fuji_util_abi_get_cat_entry:
        jmp     get_cat_entry
fuji_util_abi_get_cat_firstentry80:
        jmp     get_cat_firstentry80
fuji_util_abi_get_cat_nextentry:
        jmp     get_cat_nextentry
fuji_util_abi_get_fuji_fs_uri_addr_to_aws_tmp00:
        jmp     get_fuji_fs_uri_addr_to_aws_tmp00
fuji_util_abi_load_cur_drv_cat2:
        jmp     load_cur_drv_cat2
fuji_util_abi_load_mem_block:
        jmp     load_mem_block
fuji_util_abi_num_params:
        jmp     num_params
fuji_util_abi_osbyte_0f_flush_inbuf2:
        jmp     osbyte_0f_flush_inbuf2
fuji_util_abi_param_count:
        jmp     param_count
fuji_util_abi_param_drive_no_syntax:
        jmp     param_drive_no_syntax
fuji_util_abi_param_get_num:
        jmp     param_get_num
fuji_util_abi_param_get_string:
        jmp     param_get_string
fuji_util_abi_param_optional_drive_no:
        jmp     param_optional_drive_no
fuji_util_abi_param_syntax_error_if_null:
        jmp     param_syntax_error_if_null
fuji_util_abi_parameter_afsp:
        jmp     parameter_afsp
fuji_util_abi_parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp:
        jmp     parameter_afsp_param_syntax_error_if_null_getcatentry_fsptxtp
fuji_util_abi_parameter_fsp:
        jmp     parameter_fsp
fuji_util_abi_print_bcd_spl:
        jmp     print_bcd_spl
fuji_util_abi_print_char:
        jmp     print_char
fuji_util_abi_print_hex:
        jmp     print_hex
fuji_util_abi_print_hex_spl:
        jmp     print_hex_spl
fuji_util_abi_print_newline:
        jmp     print_newline
fuji_util_abi_print_nibble_spl:
        jmp     print_nibble_spl
fuji_util_abi_print_string:
        jmp     print_string
fuji_util_abi_print_string_spl:
        jmp     print_string_spl
fuji_util_abi_prt_filename_yoffset:
        jmp     prt_filename_yoffset
fuji_util_abi_prt_info_msg_yoffset:
        jmp     prt_info_msg_yoffset
fuji_util_abi_read_fsp_text_pointer:
        jmp     read_fsp_text_pointer
fuji_util_abi_report_error:
        jmp     report_error
fuji_util_abi_report_error_cb:
        jmp     report_error_cb
fuji_util_abi_save_cat_to_disk:
        jmp     save_cat_to_disk
fuji_util_abi_save_mem_block:
        jmp     save_mem_block
fuji_util_abi_set_curdrv_to_default:
        jmp     set_curdrv_to_default
fuji_util_abi_set_load_addr_to_host:
        jmp     set_load_addr_to_host
fuji_util_abi_y_add8:
        jmp     y_add8
fuji_util_abi_y_sub8:
        jmp     y_sub8
fuji_util_abi_end:
fuji_util_abi_signature:
        .byte   "FNABI1", 0

        .assert fuji_util_abi_end <= $8100, lderror, "utility ABI exceeds fixed $8030-$80FF area"
        .assert fuji_util_abi_signature + 7 <= $8100, lderror, "utility ABI signature exceeds fixed $8030-$80FF area"
