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
#include "fujibus_fuji_c.h"
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

/* Error functions */
extern void err_bad(void);
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
        parse_fmount_params();
    }

    //     // Check if slot is enabled and has a URI
    //     if (!fuji_mount_slot_enabled()) {
    //         // Slot is empty or disabled
    //         err_bad();
    //         return 1;
    //     }
        
    //     // Get URI length and copy URI to workspace
    //     uri_len = fuji_mount_get_uri_len();
    //     if (uri_len == 0) {
    //         err_bad();
    //         return 1;
    //     }
        
    //     // Copy URI to current FS URI buffer
    //     fuji_mount_get_uri(FUJI_CURRENT_FS_URI, uri_len);
    //     FUJI_CURRENT_FS_URI[uri_len] = '\0';  // Null-terminate
    //     *FUJI_CURRENT_FS_LEN = uri_len;
        
    //     // Update drive mapping: BBC drive -> FujiNet mount slot
    //     FUJI_DRIVE_DISK_MAP[bbc_drive] = mount_slot;
        
    //     // Store the mount slot index in workspace
    //     *FUJI_DISK_TABLE_INDEX = mount_slot;
    //     *FUJI_CURRENT_MOUNT_SLOT = mount_slot;
        
    //     // Success
    //     exit_user_ok();
    //     return 0;

    // }
}
