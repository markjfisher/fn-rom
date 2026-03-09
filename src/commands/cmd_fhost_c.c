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

/* ============================================================================
 * Constants
 * ============================================================================ */

#define FILEPROTO_VERSION     1

/* ============================================================================
 * External ASM functions (no underscore prefix in C)
 * ============================================================================ */

/* Parameter counting - returns number of parameters in A */
extern uint8_t num_params(void);

/* Get string parameter - returns string in fuji_filename_buffer, length in A, carry set on success */
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
    
    print_newline();
    
    /* Print "FS " */
    print_string((uint8_t*)"FS");
    print_space();
    
    /* Get FS URI length */
    fs_len = *FUJI_CURRENT_FS_LEN;
    
    if (fs_len == 0) {
        /* No URI set - print "(none)" */
        print_string((uint8_t*)"(none)");
    } else {
        /* Print FS URI */
        for (i = 0; i < fs_len; i++) {
            print_char(FUJI_CURRENT_FS_URI[i]);
        }
    }
    
    /* Print newline and "DIR " */
    print_newline();
    print_string((uint8_t*)"DIR");
    print_space();
    
    /* Get DIR path length */
    dir_len = *FUJI_CURRENT_DIR_LEN;
    
    if (dir_len == 0) {
        /* No DIR set - print "/" */
        print_char('/');
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
 * ============================================================================ */

bool fhost_resolve_path(uint8_t* uri_ptr, uint8_t uri_len) {
    uint8_t* tx;
    uint8_t* rx;
    uint8_t resp_len;
    uint8_t payload_len;
    uint8_t i;
    uint16_t val16;
    uint16_t uri_end;
    uint16_t path_start;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Build ResolvePath request payload */
    /* Payload: version(1) + base_uri_len(2) + base_uri + arg_len(2) + arg(0) */
    payload_len = 1 + 2 + uri_len + 2;
    
    tx[6] = FILEPROTO_VERSION;           /* version */
    
    /* base_uri_len */
    tx[7] = (uint8_t)(uri_len & 0xFF);
    tx[8] = (uint8_t)((uri_len >> 8) & 0xFF);
    
    /* base_uri */
    for (i = 0; i < uri_len; i++) {
        tx[9 + i] = uri_ptr[i];
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
    
    /* Check response */
    if (rx[6] != FILEPROTO_VERSION) {
        return false;
    }
    
    /* Get resolved_uri_len from response */
    /* Response: version(1) + flags(1) + reserved(2) + uri_len(2) + uri + dir_len(2) + dir */
    val16 = rx[9];
    val16 |= ((uint16_t)rx[10] << 8);
    
    /* Copy resolved_uri to fuji_current_fs_uri */
    for (i = 0; i < val16 && i < 80; i++) {
        FUJI_CURRENT_FS_URI[i] = rx[11 + i];
    }
    *FUJI_CURRENT_FS_LEN = (uint8_t)val16;
    
    /* Get display_path_len */
    uri_end = 11 + val16;
    val16 = rx[uri_end];
    val16 |= ((uint16_t)rx[uri_end + 1] << 8);
    
    /* Copy display_path to fuji_current_dir_path */
    path_start = uri_end + 2;
    for (i = 0; i < val16 && i < 80; i++) {
        FUJI_CURRENT_DIR_PATH[i] = rx[path_start + i];
    }
    *FUJI_CURRENT_DIR_LEN = (uint8_t)val16;
    
    return true;
}

/* ============================================================================
 * fhost_set_uri - Set current URI from user input
 * ============================================================================ */

bool fhost_set_uri(uint8_t* uri) {
    uint8_t uri_len;
    uint8_t i;
    
    /* Get URI from parameter */
    uri_len = param_get_string();
    
    if (uri_len == 0) {
        /* No parameter - error */
        err_bad_uri();
        return false;
    }
    
    /* Copy URI to fuji_filename_buffer first (what param_get_string uses) */
    /* Then copy to fuji_current_fs_uri */
    for (i = 0; i < uri_len; i++) {
        FUJI_CURRENT_FS_URI[i] = FUJI_FILENAME_BUFFER[i];
    }
    *FUJI_CURRENT_FS_LEN = uri_len;
    
    /* Try to resolve the path */
    if (!fhost_resolve_path(FUJI_CURRENT_FS_URI, uri_len)) {
        /* On failure, set display path to "/" */
        FUJI_CURRENT_DIR_PATH[0] = '/';
        FUJI_CURRENT_DIR_PATH[1] = 0;
        *FUJI_CURRENT_DIR_LEN = 1;
        
        /* Return success anyway - we kept the typed URI */
        return true;
    }
    
    /* Success */
    return true;
}

/* ============================================================================
 * cmd_fhost - Main entry point
 * ============================================================================ */

uint8_t cmd_fhost(void) {
    uint8_t params;
    
    /* Count parameters */
    params = num_params();
    
    if (params == 0) {
        /* No parameters - show current */
        fhost_show_current();
        exit_user_ok();
        return 0;
    } else if (params == 1) {
        /* One parameter - set URI */
        if (fhost_set_uri(FUJI_FILENAME_BUFFER)) {
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
