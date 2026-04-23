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
/* Host file_commands.h: kListFlagCompactOmitMetadata | kListFlagSortByName */
#define FLIST_LIST_FLAGS       0x03U
#define FLIST_PAGE_SIZE        10
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

bool flist_list_page(uint16_t start_index, uint8_t* returned_count, bool* more)
{
    uint16_t resp_len;
    uint16_t offset;
    uint16_t nret;
    uint16_t ei;
    uint8_t name_len;
    bool is_dir;
    bool compact;
    uint8_t skip_meta;
    uint8_t* buf;
    uint8_t* tx;
    uint8_t* rx;
    uint8_t uri_len;
    uint8_t* fs_uri;

    buf = fuji_data_buffer_ptr();
    fs_uri = fuji_fs_uri_ptr();
    tx = buf;
    rx = buf;
    uri_len = *FUJI_CURRENT_FS_LEN;

    tx[6] = FILEPROTO_VERSION;
    tx[7] = uri_len;
    tx[8] = 0;

    for (offset = 0; offset < uri_len; offset++) {
        tx[9 + offset] = fs_uri[offset];
    }

    offset = (uint16_t)(9 + uri_len);
    tx[offset + 0] = (uint8_t)(start_index & 0xFF);
    tx[offset + 1] = (uint8_t)((start_index >> 8) & 0xFF);
    tx[offset + 2] = FLIST_PAGE_SIZE;
    tx[offset + 3] = 0;
    tx[offset + 4] = (uint8_t)FLIST_LIST_FLAGS;

    fujibus_send_packet(FN_DEVICE_FILE,
                        FILE_CMD_LIST_DIRECTORY,
                        &tx[6],
                        (uint16_t)(8 + uri_len));

    resp_len = fujibus_receive_packet();

    if (resp_len < 13) {
        return false;
    }

    if (rx[5] != 1 || rx[6] != 0 || rx[7] != FILEPROTO_VERSION) {
        return false;
    }

    *more = ((rx[8] & 0x01) != 0);
    compact = ((rx[8] & 0x02) != 0);
    skip_meta = compact ? 0U : 16U;

    nret = (uint16_t)rx[11] | ((uint16_t)rx[12] << 8);
    *returned_count = (nret > 255U) ? 255U : (uint8_t)nret;

    if (nret == 0) {
        return true;
    }

    offset = 13;
    for (ei = 0; ei < nret; ei++) {
        if ((uint16_t)(offset + 2) > resp_len) {
            return false;
        }
        is_dir = ((rx[offset] & 0x01) != 0);
        name_len = rx[offset + 1];
        offset += 2;
        if ((uint16_t)(offset + (uint16_t)name_len + (uint16_t)skip_meta) > resp_len) {
            return false;
        }
        print_name(&rx[offset], name_len, is_dir);
        offset = (uint16_t)(offset + (uint16_t)name_len + (uint16_t)skip_meta);
    }
    return true;
}

uint8_t cmd_fs_flist(void)
{
    uint16_t start_index;
    uint8_t returned_count;
    bool more;
    uint8_t* fs_uri_cmd;
    uint8_t* host_canon;

    if (*FUJI_CURRENT_HOST_LEN == 0) {
        err_no_host_flist();
    }

    fs_uri_cmd = fuji_fs_uri_ptr();
    host_canon = fuji_host_uri_ptr();
    *FUJI_CURRENT_FS_LEN = *FUJI_CURRENT_HOST_LEN;

    if (*FUJI_CURRENT_FS_LEN >= FLIST_URI_BUFFER_SIZE) {
        err_bad_flist_path();
    }

    for (start_index = 0; start_index < (*FUJI_CURRENT_FS_LEN); start_index++) {
        fs_uri_cmd[start_index] = host_canon[start_index];
    }
    fs_uri_cmd[*FUJI_CURRENT_FS_LEN] = '\0';

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
