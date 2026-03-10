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
