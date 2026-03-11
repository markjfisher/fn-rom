/**
 * *FMOUNT Command C Implementation
 * 
 * Implements *FMOUNT command for BBC Micro:
 *   *FMOUNT <fuji slot> [<bbc drive>]
 * 
 * The first parameter is a 0-based FujiNet persisted mount slot index (0-7).
 * The optional second parameter is a BBC drive number (0-3). If omitted,
 * defaults to the current BBC drive.
 * 
 * Uses FujiBus FujiDevice (0x70) GetMount (0xFB) command.
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "fujibus_c.h"
#include "fujibus_fuji_c.h" // for setting up the mount slot in config
#include "fujibus_disk_c.h" // for actually mounting a disk
#include "cmd_fmount_c.h"
#include "commands/utils.h"

/* ============================================================================
 * External ASM functions
 * ============================================================================ */

/* Save Y register state for parameter parsing */
extern void cmd_save_args_state(void);

/* Parameter counting and parsing */
extern uint8_t num_params(void);
extern uint8_t param_get_num(void);

/* Error/Exit functions */
extern void err_bad(void);
extern void err_failed_to_mount(void);
extern void err_bad_disk_mount(void);
extern void err_not_enabled(void);
extern void exit_user_ok(void);

/* ============================================================================
 * Constants
 * ============================================================================ */

#define MAX_MOUNT_SLOT  7
#define MAX_BBC_DRIVE   3

/* ============================================================================
 * cmd_fs_fmount - Main entry point for *FMOUNT command
 * ============================================================================ */

uint8_t cmd_fs_fmount(void) {
    // MUST be called on function entry for any CMD_* function,
    // as we need to preserve the command line offset to the first arg in Y
    cmd_save_args_state();
    
    // and any further code must be in a separate block to stop the allocation of memory on the stack before we saved the Y reg
    {
        bool get_mount_ok;
        uint8_t i = 0;
        uint8_t uri_len = 0;

        parse_fmount_params();
        get_mount_ok = fuji_get_mount_slot();
        if (!get_mount_ok) {
            err_failed_to_mount();
        }

        // Payload:
        // rx[7] = chosen slot
        // rx[8] = enabled (1 = true, 0 = false)
        // rx[9] = uri_len
        // rx[10... 10 + uri_length - 1] = uri
        // rs[10+uri_length] = mode len
        // rs[10+uri_length + 1] = mode string (e.g. "rw+", defaults to "r" when not enabled)

        // example:
        // 02 00 00 01 72 == slot 2, disabled, no uri string, 1 byte, "r"

        // check enabled flag, FUJI_RX_BUFFER[7] bit 0
        if (FUJI_RX_BUFFER[8] == 0) {
            err_not_enabled();
        }

        // copy the uri to the FS uri
        uri_len = FUJI_RX_BUFFER[9];
        FUJI_CURRENT_FS_URI[0] = '\0';      // in case the length is 0, pre-write a nul byte. The buffer

        for (i = 0; i < uri_len; i++) {
            FUJI_CURRENT_FS_URI[i] = FUJI_RX_BUFFER[10 + i + uri_len];
        }
        *FUJI_CURRENT_FS_LEN = uri_len;

        // Now create a disk mount request
        // TODO: sort out r/w modes, 1=read-only, although we need to support that in the fujinet too.
        if (!fujibus_disk_mount(0)) {
            err_bad_disk_mount();
        }

        exit_user_ok();
        return 0;

    }

}
