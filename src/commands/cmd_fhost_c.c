/**
 * *FHOST Command C Implementation
 * 
 * Implements *FHOST and *FFS commands for BBC Micro:
 *   *FHOST       - Show current FS and DIR
 *   *FHOST <uri> - Set current filesystem URI
 * 
 * Uses FujiBus FileDevice (0xFE) ResolvePath (0x05) command.
 *
 * Supported forms:
 *   *FHOST
 *       Print the currently selected full URI and the current human-facing path.
 *
 *   *FHOST <uri>
 *   *FFS   <uri>
 *       Store a new current filesystem selection and ask FileDevice ResolvePath
 *       to canonicalize it immediately.
 *
 * Design split:
 * - FHOST/FFS are the URI-facing commands.
 * - The BBC stores two related values:
 *     _fuji_current_fs_uri   -> canonical full URI for machine/protocol use
 *     _fuji_current_dir_path -> display path for human-facing output only
 * - URI and path semantics are intentionally delegated to FujiNet-NIO via
 *   FileDevice ResolvePath rather than reimplemented in 6502.
 *
 * FHOST vs FMOUNT: FMOUNT reads the FujiNet persisted mount table (GetMount(slot)).
 * FHOST only sets the BBC "current" URI. So that "*FMOUNT 0 0" works after "*FHOST <uri>",
 * we persist the newly set URI to FujiNet slot 0 after ResolvePath success.
 *
 *
 * ResolvePath usage here:
 * - baseUriLen/baseUri are taken from the just-stored fuji_current_fs_* fields
 * - argLen is set to 0 so NIO canonicalizes the URI “as-is”
 * - on success the helper refreshes both URI and display-path state
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
    uint8_t dir_len;
    uint8_t i;
    uint8_t *none_string = "(none)";

    print_newline();
    
    /* Print "FS " */
    print_string((uint8_t*)"HOST: ");
    
    if ((*FUJI_CURRENT_HOST_LEN) == 0) {
        print_string(none_string);
    } else {
        /* Print FS URI */
        for (i = 0; i < (*FUJI_CURRENT_HOST_LEN); i++) {
            print_char(FUJI_CURRENT_HOST_URI[i]);
        }
    }
    
    /* Print newline and "DIR " */
    print_newline();
    print_string((uint8_t*)"PATH: ");
    
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
 * Uses workspace: FUJI_CURRENT_HOST_URI, FUJI_CURRENT_HOST_LEN
 * ============================================================================ */

// This will all be rewritten in ASM when it's all working.
// cc65 code is SO inefficient for local vars. SO many pointer indirection instructions for accessing stack locations
// also need to rethink on whether we want to support 16 bit sizes, as they kill space.

bool fhost_resolve_path(void) {
    uint16_t resp_len;
    uint8_t i;
    uint16_t uri_end;
    uint8_t dir_len;
    
    /* Build ResolvePath request payload */
    /* Payload: version(1) + base_uri_len(2) + base_uri + arg_len(2) + arg(0) */    
    FUJI_TX_BUFFER[6] = FILEPROTO_VERSION;           /* version */
    
    /* base_uri_len */
    FUJI_TX_BUFFER[7] = *FUJI_CURRENT_HOST_LEN;
    FUJI_TX_BUFFER[8] = 0;
    
    /* base_uri */
    for (i = 0; i < (*FUJI_CURRENT_HOST_LEN); i++) {
        FUJI_TX_BUFFER[9 + i] = FUJI_CURRENT_HOST_URI[i];
    }
    
    /* arg_len = 0 */
    FUJI_TX_BUFFER[9 + (*FUJI_CURRENT_HOST_LEN)] = 0;
    FUJI_TX_BUFFER[10 + (*FUJI_CURRENT_HOST_LEN)] = 0;
    
    /* Send packet */
    // payload_len = 1 + 2 + uri_len + 2;
    fujibus_send_packet(FN_DEVICE_FILE, FILE_CMD_RESOLVE_PATH, &FUJI_TX_BUFFER[6], 5 + (*FUJI_CURRENT_HOST_LEN));
    
    /* Receive response */
    
    resp_len = fujibus_receive_packet();
    
    if (resp_len == 0) {
        return false;
    }
    
    /* FujiBus response structure: */
    /* FUJI_RX_BUFFER[0-4]: header (device, cmd, length lo/hi, checksum) */
    /* FUJI_RX_BUFFER[5]: descr (0x01 = 1 param following = status) */
    /* FUJI_RX_BUFFER[6]: status param (from addParamU8) = 0x00 for success */
    /* FUJI_RX_BUFFER[7]: payload version */
    /* FUJI_RX_BUFFER[8]: payload flags */
    /* FUJI_RX_BUFFER[9-10]: payload reserved */
    /* FUJI_RX_BUFFER[11-12]: uri_len */
    /* FUJI_RX_BUFFER[13]: uri starts here */
    /* After uri: dir_len (2 bytes), then dir */
    
    /* Check descriptor: 1 param (status) and its value */
    if (FUJI_RX_BUFFER[5] != 1 || FUJI_RX_BUFFER[6] != 0 || FUJI_RX_BUFFER[7] != FILEPROTO_VERSION) {
        return false;
    }

    /* Get resolved_uri_len from response */
    *FUJI_CURRENT_HOST_LEN = FUJI_RX_BUFFER[11];  /* Low byte of uri_len */
    
    /* Copy resolved_uri to fuji_current_fs_uri */
    /* URI starts at FUJI_RX_BUFFER[13] (after version, flags, reserved, uri_len) */
    for (i = 0; i < (*FUJI_CURRENT_HOST_LEN); i++) {
        FUJI_CURRENT_HOST_URI[i] = FUJI_RX_BUFFER[13 + i];
    }
    *FUJI_CURRENT_HOST_LEN = *FUJI_CURRENT_HOST_LEN;
    
    /* Get display_path_len */
    /* uri ends at FUJI_RX_BUFFER[13 - 1 + uri_len], dir_len starts at FUJI_RX_BUFFER[13 + uri_len] */
    uri_end = 12 + (*FUJI_CURRENT_HOST_LEN);
    dir_len = FUJI_RX_BUFFER[uri_end + 1];  /* Low byte of dir_len */
    
    /* Copy display_path to fuji_current_dir_path */
    // path_start = uri_end + 3;
    for (i = 0; i < dir_len; i++) {
        FUJI_CURRENT_DIR_PATH[i] = FUJI_RX_BUFFER[uri_end + 3 + i];
    }
    *FUJI_CURRENT_DIR_LEN = dir_len;
    
    return true;
}

/* ============================================================================
 * fhost_set_uri - Set current URI from user input
 * Uses workspace: FUJI_FILENAME_BUFFER, FUJI_CURRENT_HOST_URI, FUJI_ERROR_FLAG
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
        FUJI_CURRENT_HOST_URI[i] = FUJI_FILENAME_BUFFER[i];
    }
    *FUJI_CURRENT_HOST_LEN = uri_len;

    /* Try to resolve the path */
    if (!fhost_resolve_path()) {
        /* On failure, clear both URI and DIR to indicate invalid state */
        /* Clear the URI - null-terminate and set zero length */
        FUJI_CURRENT_HOST_URI[0] = '\0';
        *FUJI_CURRENT_HOST_LEN = 0;
        
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
