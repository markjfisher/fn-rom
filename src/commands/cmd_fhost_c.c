/**
 * *FHOST Command C Implementation
 * 
 * Implements *FHOST and *FFS commands for BBC Micro:
 *   *FHOST       - Show current FS and DIR
 *   *FHOST <uri> - Set current filesystem URI
 * 
 * Uses FujiBus FileDevice (0xFE) ResolvePath (0x05) command.
 * 
 * Request format:
 *   u8 version
 *   u16 base_uri_len (LE)
 *   u8[] base_uri
 *   u16 arg_len (LE) = 0
 * 
 * Response format:
 *   u8 version
 *   u8 flags (bit0=isDir, bit1=exists)
 *   u16 reserved
 *   u16 resolved_uri_len
 *   u8[] resolved_uri
 *   u16 display_path_len
 *   u8[] display_path
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "fujibus_c.h"
#include "cmd_fhost_c.h"
#include "commands/utils.h"

/* ============================================================================
 * Constants
 * ============================================================================ */

#define FILEPROTO_VERSION     1
#define MAX_PATH_LEN          64

/* ============================================================================
 * External ASM functions (no underscore prefix in C)
 * ============================================================================ */

/* Parameter counting - returns number of parameters in A */
extern uint8_t num_params(void);

/* Get string parameter - returns string in fuji_filename_buffer, length in A */
extern uint8_t param_get_string(void);

/* Print functions */
extern void print_char(uint8_t c);
extern void print_newline(void);
extern void print_space(void);

/* Error functions */
extern void err_bad(void);
extern void err_bad_uri(void);
extern void exit_user_ok(void);

/* ============================================================================
 * Helper: Print NUL-terminated string
 * ============================================================================ */

static void print_string(uint8_t* s) {
    while (*s) {
        print_char(*s++);
    }
}

/* ============================================================================
 * fhost_show_current - Display current FS and DIR
 * ============================================================================ */

void fhost_show_current(void) {
    uint8_t fs_len;
    uint8_t dir_len;
    uint8_t i;
    uint8_t *none_string = "(none)";

    print_newline();
    
    /* Print "FS " */
    print_string((uint8_t*)"FS ");
    
    /* Get FS URI length */
    fs_len = *FUJI_CURRENT_FS_LEN;
    
    if (fs_len == 0) {
        print_string(none_string);
    } else {
        /* Print FS URI */
        for (i = 0; i < fs_len; i++) {
            print_char(FUJI_CURRENT_FS_URI[i]);
        }
    }
    
    /* Print newline and "DIR " */
    print_newline();
    print_string((uint8_t*)"DIR ");
    
    /* Get DIR path length */
    dir_len = *FUJI_CURRENT_DIR_LEN;
    
    if (dir_len == 0) {
        print_string(none_string);
    } else {
        /* Print DIR path */
        for (i = 0; i < dir_len; i++) {
            print_char(FUJI_CURRENT_DIR_PATH[i]);
        }
    }
    
    print_newline();
}

/* ============================================================================
 * fhost_resolve_path - Send ResolvePath to FujiNet
 * Uses workspace: FUJI_CURRENT_FS_URI, FUJI_CURRENT_FS_LEN
 * ============================================================================ */

bool fhost_resolve_path(void) {
    uint8_t* tx;
    uint8_t* rx;
    uint16_t resp_len;
    uint16_t payload_len;
    uint8_t i;
    uint16_t uri_end;
    uint16_t path_start;
    uint8_t uri_len;
    uint8_t dir_len;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Get URI from workspace */
    uri_len = *FUJI_CURRENT_FS_LEN;
    
    /* Build ResolvePath request payload */
    /* Payload: version(1) + base_uri_len(2) + base_uri + arg_len(2) + arg(0) */
    payload_len = 1 + 2 + uri_len + 2;
    
    tx[6] = FILEPROTO_VERSION;           /* version */
    
    /* base_uri_len */
    tx[7] = (uint8_t)(uri_len & 0xFF);
    tx[8] = (uint8_t)((uri_len >> 8) & 0xFF);
    
    /* base_uri */
    for (i = 0; i < uri_len; i++) {
        tx[9 + i] = FUJI_CURRENT_FS_URI[i];
    }
    
    /* arg_len = 0 */
    tx[9 + uri_len] = 0;
    tx[10 + uri_len] = 0;
    
    /* Send packet */
    fujibus_send_packet(FN_DEVICE_FILE, FILE_CMD_RESOLVE_PATH, &tx[6], payload_len);
    
    /* Receive response */
    
    resp_len = fujibus_receive_packet();
    
    if (resp_len == 0) {
        return false;
    }
    
    /* FujiBus response structure: */
    /* rx[0-4]: header (device, cmd, length lo/hi, checksum) */
    /* rx[5]: descr (0x01 = 1 param following = status) */
    /* rx[6]: status param (from addParamU8) = 0x00 for success */
    /* rx[7]: payload version */
    /* rx[8]: payload flags */
    /* rx[9-10]: payload reserved */
    /* rx[11-12]: uri_len */
    /* rx[13]: uri starts here */
    /* After uri: dir_len (2 bytes), then dir */
    
    /* Check descriptor: 1 param (status) */
    if (rx[5] != 1) {
        return false;
    }
    
    /* Check status: 0 = success */
    if (rx[6] != 0) {
        return false;
    }
    
    /* Check payload version */
    if (rx[7] != FILEPROTO_VERSION) {
        return false;
    }
    
    /* Get resolved_uri_len from response */
    uri_len = rx[11];  /* Low byte of uri_len */
    
    /* Copy resolved_uri to fuji_current_fs_uri */
    /* URI starts at rx[13] (after version, flags, reserved, uri_len) */
    for (i = 0; i < uri_len && i < MAX_PATH_LEN; i++) {
        FUJI_CURRENT_FS_URI[i] = rx[13 + i];
    }
    *FUJI_CURRENT_FS_LEN = uri_len;
    
    /* Get display_path_len */
    /* uri ends at rx[12 + uri_len], dir_len starts at rx[13 + uri_len] */
    uri_end = 13 + uri_len - 1;
    dir_len = rx[uri_end + 1];  /* Low byte of dir_len */
    
    /* Copy display_path to fuji_current_dir_path */
    path_start = uri_end + 3;
    for (i = 0; i < dir_len; i++) {
        FUJI_CURRENT_DIR_PATH[i] = rx[path_start + i];
    }
    *FUJI_CURRENT_DIR_LEN = dir_len;
    
    return true;
}

/* ============================================================================
 * fhost_set_uri - Set current URI from user input
 * Uses workspace: FUJI_FILENAME_BUFFER, FUJI_CURRENT_FS_URI, FUJI_ERROR_FLAG
 * ============================================================================ */

bool fhost_set_uri(void) {
    uint8_t uri_len;
    uint8_t i;
    
    /* Get URI from parameter - stored in fuji_filename_buffer */
    uri_len = param_get_string();
    
    // Check for truncation - fuji_error_flag = 1 means truncated
    // or no parameter
    if (*FUJI_ERROR_FLAG != 0 || uri_len == 0) {
        /* String was truncated */
        err_bad_uri();
    }
    
    /* Copy URI from fuji_filename_buffer to fuji_current_fs_uri */
    for (i = 0; i < uri_len; i++) {
        FUJI_CURRENT_FS_URI[i] = FUJI_FILENAME_BUFFER[i];
    }
    *FUJI_CURRENT_FS_LEN = uri_len;

    /* Try to resolve the path */
    if (!fhost_resolve_path()) {
        /* On failure, clear both URI and DIR to indicate invalid state */
        /* Clear the URI - null-terminate and set zero length */
        FUJI_CURRENT_FS_URI[0] = '\0';
        *FUJI_CURRENT_FS_LEN = 0;
        
        /* Clear the DIR - null-terminate and set zero length */
        /* When dir_len is 0, fhost_show_current displays "/" as fallback */
        FUJI_CURRENT_DIR_PATH[0] = '\0';
        *FUJI_CURRENT_DIR_LEN = 0;
        
        /* Return success - state cleared */
        return true;
    }
    
    /* Success */
    return true;
}

/* ============================================================================
 * cmd_fs_fhost - Main entry point
 * ============================================================================ */

uint8_t cmd_fs_fhost(void) {
    // MUST be called on function entry for any CMD_* function,
    // as we need to preserve the command line offset to the first arg in Y
    cmd_save_args_state();

    // ensure no params are created on the stack before calling above
    {
        uint8_t params;
        uint8_t as_char;
        uint8_t *a;
    
        params = num_params();
        a = params;
    
        if (params == 0) {
            /* No parameters - show current */
            fhost_show_current();
            exit_user_ok();
            return 0;
        } else if (params == 1) {
            /* One parameter - set URI */
            if (fhost_set_uri()) {
                exit_user_ok();
                return 0;
            } else {
                return 1;
            }
        } else {
            /* Too many parameters */
            err_bad();
            return 1;
        }
    }
}
