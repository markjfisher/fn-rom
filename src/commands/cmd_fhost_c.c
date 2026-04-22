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
 * - ResolvePath returns uri_len + path_len + path; the resolved URI string contains
 *   the directory as a suffix. We store canonical host URI in PWS (fuji_host_uri_ptr) plus
 *   FUJI_CURRENT_HOST_LEN and FUJI_CURRENT_DIR_LEN; fuji_dir_path_ptr() returns
 *   host_uri + (host_len - dir_len) for PATH display.
 * - URI and path semantics are intentionally delegated to FujiNet-NIO via
 *   FileDevice ResolvePath rather than reimplemented in 6502.
 *
 * FHOST vs FMOUNT: FMOUNT reads the FujiNet persisted mount table (GetMount(slot)).
 * FHOST only sets the BBC "current" URI. So that "*FMOUNT 0 0" works after "*FHOST <uri>",
 * we persist the newly set URI to FujiNet slot 0 after ResolvePath success.
 */

#include <stdint.h>
#include <stdbool.h>
#include "cmd_fhost_c.h"
#include "fujibus_c.h"

extern void cmd_save_args_state(void);
extern uint8_t parse_fhost_params(void);

extern void exit_user_ok(void);
extern void err_set_uri(void);

/* FujiNet interface - use wrapper for proper layering */
extern uint8_t fuji_resolve_path(void);

/* Print functions - from print_utils.s */
extern void print_char(uint8_t c);
extern void print_newline(void);

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
    uint8_t *dir_path;
    uint8_t *host_uri;

    dir_path = fuji_dir_path_ptr();
    host_uri = fuji_host_uri_ptr();

    print_newline();
    
    /* Print "FS " */
    print_string((uint8_t*)"HOST: ");
    
    if ((*FUJI_CURRENT_HOST_LEN) == 0) {
        print_string(none_string);
    } else {
        /* Print FS URI */
        for (i = 0; i < (*FUJI_CURRENT_HOST_LEN); i++) {
            print_char(host_uri[i]);
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
            print_char(dir_path[i]);
        }
    }
    
    print_newline();
}

/* ============================================================================
 * fhost_set_uri - Set current URI from user input
 * Uses workspace: FUJI_FILENAME_BUFFER, host URI slot (fuji_host_uri_ptr), FUJI_ERROR_FLAG
 * ============================================================================ */

bool fhost_set_uri(void) {
    uint8_t uri_len;
    uint8_t i;
    uint8_t *host_uri;

    uri_len = *FUJI_FILENAME_LEN;
    host_uri = fuji_host_uri_ptr();

    /* Copy URI from fuji_filename_buffer into PWS host slot */
    for (i = 0; i < uri_len; i++) {
        host_uri[i] = FUJI_FILENAME_BUFFER[i];
    }
    *FUJI_CURRENT_HOST_LEN = uri_len;

    /* Try to resolve the path */
    if (!fuji_resolve_path()) {
        /* On failure, clear both URI and DIR to indicate invalid state */
        host_uri[0] = '\0';
        *FUJI_CURRENT_HOST_LEN = 0;
        *FUJI_CURRENT_DIR_LEN = 0;
        
        return false;
    }
    
    /* Success */
    return true;
}

/* ============================================================================
 * cmd_fs_fhost - Main entry point
 * ============================================================================ */

uint8_t cmd_fs_fhost(void) {
    /* MUST be called first to save Y register for param parsing */
    cmd_save_args_state();

    if (parse_fhost_params() == 0) {
        fhost_show_current();
    } else {
        if (!fhost_set_uri()) {
            err_set_uri();
        }
    }

    exit_user_ok();
    return 0;

}
