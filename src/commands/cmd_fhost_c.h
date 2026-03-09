/**
 * *FHOST Command C Implementation - Header File
 * 
 * Implements *FHOST and *FFS commands for BBC Micro:
 *   *FHOST       - Show current FS and DIR
 *   *FHOST <uri> - Set current filesystem URI
 * 
 * Uses FujiBus FileDevice (0xFE) ResolvePath (0x05) command.
 */

#ifndef CMD_FHOST_C_H
#define CMD_FHOST_C_H

#include <stdint.h>
#include <stdbool.h>
#include "fujibus_c.h"

/* ============================================================================
 * Workspace addresses (from os.s)
 * ============================================================================ */

/* Current filesystem URI buffer (80 bytes at 0x1200) */
#define FUJI_CURRENT_FS_URI   ((uint8_t*)0x1200)

/* Current directory path buffer (80 bytes at 0x1250) */
#define FUJI_CURRENT_DIR_PATH ((uint8_t*)0x1250)

/* Current filesystem URI length (at 0x10C8) */
#define FUJI_CURRENT_FS_LEN   ((uint8_t*)0x10C8)

/* Current directory path length (at 0x10C9) */
#define FUJI_CURRENT_DIR_LEN   ((uint8_t*)0x10C9)

/* Error flag - 0 = OK, 1 = truncated */
#define FUJI_ERROR_FLAG       ((uint8_t*)0x10DA)

/* Filename buffer at 0x1000 */
#define FUJI_FILENAME_BUFFER  ((uint8_t*)0x1000)

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * Main entry point for *FHOST command
 * Called from ASM command dispatcher
 * Returns: 0 on success, non-zero on error
 */
uint8_t cmd_fs_fhost(void);

/**
 * Show current filesystem and directory
 * Prints: FS <uri> and DIR <path>
 */
void fhost_show_current(void);

/**
 * Set current filesystem from workspace (fuji_filename_buffer)
 * @return true on success
 */
bool fhost_set_uri(void);

/**
 * ResolvePath via FujiNet using workspace variables
 * Reads from FUJI_CURRENT_FS_URI and FUJI_CURRENT_FS_LEN
 * @return true on success
 */
bool fhost_resolve_path(void);

#endif /* CMD_FHOST_C_H */
