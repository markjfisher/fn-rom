#ifndef CMD_FIN_C_H
#define CMD_FIN_C_H

#include <stdint.h>
#include "fujibus_c.h"
#include "fujibus_fuji_c.h"

/**
 * Main entry point for *FIN command
 * Returns: 0 on success, non-zero on error, TODO: it exits on error, so could ditch return value
 */
uint8_t cmd_fs_fin(void);

#endif /* CMD_FIN_C_H */
