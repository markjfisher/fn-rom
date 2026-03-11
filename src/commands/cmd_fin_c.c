/**
 * cmd_fs_fin - Handle *FIN command
 *
 * Supported forms:
 *   *FIN <filename>
 *       Store a URI into the current/default persisted FujiNet mount slot.
 *
 *   *FIN <mount slot> <filename>
 *       Change the current/default persisted FujiNet mount slot, then store the
 *       URI into that slot.
 *
 * Design split:
 * - FIN does not perform a live BBC drive mount.
 * - Instead it writes a URI into the FujiDevice persisted mount table using the
 *   FujiDevice SetMount protocol through fuji_set_mount_slot.
 * - FMOUNT is the separate command that bridges a persisted FujiNet slot onto a
 *   BBC DFS drive.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "fujibus_c.h"
#include "fujibus_fuji_c.h"
#include "cmd_fin_c.h"

/* ASM functions from fuji_mount.s */
extern bool fuji_set_slot(void);

/* External ASM functions */
extern void cmd_save_args_state(void);
extern void parse_fin_params(void);
extern void exit_user_ok(void);
extern void err_bad(void);
extern void err_no_host(void);
extern void err_set_mount_failed(void);

/**
 * Build the full URI from host + filename
 * Stores result in FUJI_CURRENT_FS_URI and sets FUJI_CURRENT_FS_LEN
 */
static void build_full_uri() {
    uint8_t host_len;
    uint8_t i;
    uint8_t* host_uri;
    uint8_t* full_uri;
    uint8_t filename_len;

    filename_len = *FUJI_FILENAME_LEN;
    
    host_len = *FUJI_CURRENT_HOST_LEN;
    host_uri = FUJI_CURRENT_HOST_URI;
    full_uri = FUJI_CURRENT_FS_URI;
    
    /* Copy host URI */
    for (i = 0; i < host_len; i++) {
        full_uri[i] = host_uri[i];
    }
    
    /* Append filename */
    for (i = 0; i < filename_len; i++) {
        full_uri[host_len + i] = FUJI_FILENAME_BUFFER[i];
    }
    
    /* Null terminate and store length */
    full_uri[host_len + filename_len] = '\0';
    *FUJI_CURRENT_FS_LEN = host_len + filename_len;
}

/**
 * Main entry point for *FIN command
 */
uint8_t cmd_fs_fin(void) {
    /* MUST be called first to save Y register for param parsing */
    cmd_save_args_state();
    
    /* Now parse parameters in ASM - this handles success/exit internally */
    parse_fin_params();
    
    /* If we get here, ASM parsing succeeded and stored values in globals */
    /* Now do the FujiNet communication in C */
    
    /* Check if current host URI is set */
    if (*FUJI_CURRENT_HOST_LEN == 0) {
        /* No host set - error */
        err_no_host();
    }
    
    /* Build full URI = host + filename */
    build_full_uri();
    
    /* Call high-level interface - handles transaction and hardware selection */
    if (!fuji_set_slot()) {
        err_set_mount_failed();
    }
    
    /* Success */
    exit_user_ok();
    return 0;

}
