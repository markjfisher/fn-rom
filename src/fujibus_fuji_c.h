/**
 * FujiBus FujiDevice C Interface - Header File
 * 
 * Provides C functions for interacting with FujiDevice (FujiNet)
 * Mount table operations via FujiBus protocol.
 * 
 * NOTE: Functions in this file are FujiBus protocol-specific.
 * For generic interface, use fuji_* functions in fuji_mount.s
 */

#ifndef FUJIBUS_FUJI_C_H
#define FUJIBUS_FUJI_C_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * Constants
 * ============================================================================ */

/* Mount response offsets (after FujiBus header + status param) */
#define MOUNT_RESP_FLAGS         0  /* enabled flag */
#define MOUNT_RESP_URI_LEN       1  /* URI length */
#define MOUNT_RESP_URI           2  /* URI starts here */

/* ============================================================================
 * Functions - FujiBus protocol specific
 * ============================================================================ */

/**
 * fujibus_get_mount_slot - Get mount record for a slot (FujiBus protocol)
 * 
 * Sends GetMount command to FujiNet for the specified slot.
 * On success, the mount record is stored in FUJI_DATA_BUFFER:
 *   [flags][uri_len][uri][mode_len][mode]
 * 
 * Uses the global fuji mount slot index for slot number.
 * @return true on success, false on failure
 */
bool fujibus_get_mount_slot();

/**
 * fujibus_set_mount_slot - Set mount record for a slot (FujiBus protocol)
 * 
 * Sends SetMount command to FujiNet to persist a mount entry.
 * Payload format: [slot][flags][uri_len][uri][mode_len][mode]
 * 
 * Uses global fuji_disk_slot for slot number.
 * @return true on success, false on failure
 */
bool fujibus_set_mount_slot();

#endif /* FUJIBUS_FUJI_C_H */
