#include <stdint.h>
#include <stdbool.h>
#include "cmd_flist_c.h"
#include "fujibus_c.h"

extern void cmd_save_args_state(void);
extern uint8_t parse_flist_params(void);

extern void exit_user_ok(void);
extern void err_no_host_flist(void);
extern void err_bad_flist_path(void);
extern void err_flist_failed(void);

extern void print_char(uint8_t c);
extern void print_newline(void);

#define FILEPROTO_VERSION      1
#define FILE_CMD_LIST_DIRECTORY 0x02
#define FLIST_PAGE_SIZE        1
#define FLIST_URI_BUFFER_SIZE  80

void print_name(const uint8_t* s, uint8_t len, bool is_dir)
{
    uint8_t i;

    for (i = 0; i < len; i++) {
        print_char(s[i]);
    }

    if (is_dir) {
        print_char('/');
    }

    print_newline();
}

bool flist_resolve_target(void)
{
    uint16_t resp_len;
    uint8_t i;
    uint8_t base_len;
    uint8_t arg_len;
    uint8_t* buf;
    uint8_t* tx;
    uint8_t* rx;

    buf = fuji_data_buffer_ptr();
    tx = buf;
    rx = buf;
    base_len = *FUJI_CURRENT_HOST_LEN;
    arg_len = *FUJI_FILENAME_LEN;

    if (base_len == 0) {
        return false;
    }

    tx[6] = FILEPROTO_VERSION;
    tx[7] = base_len;
    tx[8] = 0;

    for (i = 0; i < base_len; i++) {
        tx[9 + i] = FUJI_CURRENT_HOST_URI[i];
    }

    tx[9 + base_len] = arg_len;
    tx[10 + base_len] = 0;

    for (i = 0; i < arg_len; i++) {
        tx[11 + base_len + i] = FUJI_FILENAME_BUFFER[i];
    }

    fujibus_send_packet(FN_DEVICE_FILE,
                        FILE_CMD_RESOLVE_PATH,
                        &tx[6],
                        (uint16_t)(5 + base_len + arg_len));

    resp_len = fujibus_receive_packet();

    if (resp_len < 13) {
        return false;
    }

    if (rx[5] != 1 || rx[6] != 0 || rx[7] != FILEPROTO_VERSION) {
        return false;
    }

    if (rx[12] != 0) {
        return false;
    }

    if (rx[11] >= FLIST_URI_BUFFER_SIZE) {
        return false;
    }

    if ((rx[8] & 0x03) != 0x03) {
        return false;
    }

    *FUJI_CURRENT_FS_LEN = rx[11];

    for (i = 0; i < (*FUJI_CURRENT_FS_LEN); i++) {
        FUJI_CURRENT_FS_URI[i] = rx[13 + i];
    }

    FUJI_CURRENT_FS_URI[*FUJI_CURRENT_FS_LEN] = '\0';
    return true;
}

bool flist_list_page(uint16_t start_index, uint8_t* returned_count, bool* more)
{
    uint16_t resp_len;
    uint16_t offset;
    uint8_t name_len;
    bool is_dir;
    uint8_t* buf;
    uint8_t* tx;
    uint8_t* rx;
    uint8_t uri_len;

    buf = fuji_data_buffer_ptr();
    tx = buf;
    rx = buf;
    uri_len = *FUJI_CURRENT_FS_LEN;

    tx[6] = FILEPROTO_VERSION;
    tx[7] = uri_len;
    tx[8] = 0;

    for (offset = 0; offset < uri_len; offset++) {
        tx[9 + offset] = FUJI_CURRENT_FS_URI[offset];
    }

    offset = (uint16_t)(9 + uri_len);
    tx[offset + 0] = (uint8_t)(start_index & 0xFF);
    tx[offset + 1] = (uint8_t)((start_index >> 8) & 0xFF);
    tx[offset + 2] = FLIST_PAGE_SIZE;
    tx[offset + 3] = 0;

    fujibus_send_packet(FN_DEVICE_FILE,
                        FILE_CMD_LIST_DIRECTORY,
                        &tx[6],
                        (uint16_t)(7 + uri_len));

    resp_len = fujibus_receive_packet();

    if (resp_len < 13) {
        return false;
    }

    if (rx[5] != 1 || rx[6] != 0 || rx[7] != FILEPROTO_VERSION) {
        return false;
    }

    *more = ((rx[8] & 0x01) != 0);
    if (rx[12] != 0) {
        return false;
    }

    *returned_count = rx[11];
    if (*returned_count == 0) {
        return true;
    }

    offset = 13;
    if ((uint16_t)(offset + 2) > resp_len) {
        return false;
    }

    is_dir = ((rx[offset] & 0x01) != 0);
    name_len = rx[offset + 1];
    offset += 2;

    if ((uint16_t)(offset + name_len + 16) > resp_len) {
        return false;
    }

    print_name(&rx[offset], name_len, is_dir);
    return true;
}

uint8_t cmd_fs_flist(void)
{
    cmd_save_args_state();

    {
        uint8_t param_count;
        uint16_t start_index;
        uint8_t returned_count;
        bool more;

        if (*FUJI_CURRENT_HOST_LEN == 0) {
            err_no_host_flist();
        }

        param_count = parse_flist_params();

        if (param_count == 0) {
            *FUJI_CURRENT_FS_LEN = *FUJI_CURRENT_HOST_LEN;

            if (*FUJI_CURRENT_FS_LEN >= FLIST_URI_BUFFER_SIZE) {
                err_bad_flist_path();
            }

            for (start_index = 0; start_index < (*FUJI_CURRENT_FS_LEN); start_index++) {
                FUJI_CURRENT_FS_URI[start_index] = FUJI_CURRENT_HOST_URI[start_index];
            }
            FUJI_CURRENT_FS_URI[*FUJI_CURRENT_FS_LEN] = '\0';
        } else {
            if (!flist_resolve_target()) {
                err_bad_flist_path();
            }
        }

        print_newline();

        start_index = 0;
        more = true;

        while (more) {
            if (!flist_list_page(start_index, &returned_count, &more)) {
                err_flist_failed();
            }

            if (returned_count == 0) {
                break;
            }

            start_index = (uint16_t)(start_index + returned_count);
        }

        exit_user_ok();
        return 0;
    }
}
