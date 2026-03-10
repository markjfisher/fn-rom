/**
 * *FMOUNT Command C Implementation - Header File
 * 
 * Implements *FMOUNT command for BBC Micro:
 *   *FMOUNT <fuji slot> [<bbc drive>]
 * 
 * Uses FujiBus FujiDevice (0x70) GetMount (0xFB) command.
 */

#ifndef CMD_FMOUNT_C_H
#define CMD_FMOUNT_C_H

#include <stdint.h>
#include <stdbool.h>
#include "fujibus_fuji_c.h"
#include "fujibus_c.h"

/* ============================================================================
 * Workspace addresses (from os.s)
 * ============================================================================ */

/* FujiNet drive-to-disk mapping (4 bytes: drives 0-3) at 0x10DB */
#define FUJI_DRIVE_DISK_MAP      ((uint8_t*)0x10DB)

/* Current mount slot index at 0x10D4 */
#define FUJI_DISK_TABLE_INDEX    ((uint8_t*)0x10D4)

/* Current drive (0-3) at 0x10CD */
#define CURRENT_DRV               ((uint8_t*)0x10CD)

/* Current mount slot at 0x10EA */
#define FUJI_CURRENT_MOUNT_SLOT  ((uint8_t*)0x10EA)

/* Current filesystem URI buffer at 0x1200 */
#define FUJI_CURRENT_FS_URI       ((uint8_t*)0x1200)

/* Current filesystem URI length at 0x10E8 */
#define FUJI_CURRENT_FS_LEN       ((uint8_t*)0x10E8)

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * Main entry point for *FMOUNT command
 * Called from ASM command dispatcher
 * Returns: 0 on success, non-zero on error
 */
uint8_t cmd_fs_fmount(void);

extern void parse_fmount_params();

#endif /* CMD_FMOUNT_C_H */
