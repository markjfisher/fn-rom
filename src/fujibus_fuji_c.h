/**
 * FujiBus FujiDevice C Interface - Header File
 * 
 * Provides C functions for interacting with FujiDevice (FujiNet)
 * Mount table operations.
 */

#ifndef FUJIBUS_FUJI_C_H
#define FUJIBUS_FUJI_C_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * Constants
 * ============================================================================ */

/* FujiDevice (0x70) - FujiNet device */
#define FN_DEVICE_FUJI           0x70
#define FUJI_CMD_GET_MOUNT       0xFB

/* Mount response offsets (after FujiBus header + status param) */
#define MOUNT_RESP_FLAGS         0  /* enabled flag */
#define MOUNT_RESP_URI_LEN       1  /* URI length */
#define MOUNT_RESP_URI           2  /* URI starts here */

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * fuji_get_mount_slot - Get mount record for a slot
 * 
 * Sends GetMount command to FujiNet for the specified slot.
 * On success, the mount record is stored in FUJI_RX_BUFFER:
 *   [flags][uri_len][uri][mode_len][mode]
 * 
 * @param slot Slot index (0-7)
 * @return true on success, false on failure
 */
bool fuji_get_mount_slot(uint8_t slot);

/**
 * Check if mount slot is enabled
 * Must be called after fuji_get_mount_slot() returns true
 * @return true if slot is enabled and has a URI
 */
bool fuji_mount_slot_enabled(void);

/**
 * Get URI length from last mount response
 * @return URI length in bytes
 */
uint8_t fuji_mount_get_uri_len(void);

/**
 * Copy URI from mount response to destination buffer
 * @param dest Destination buffer (must be at least uri_len bytes)
 * @param max_len Maximum bytes to copy
 * @return Actual bytes copied
 */
uint8_t fuji_mount_get_uri(uint8_t* dest, uint8_t max_len);

/**
 * Get mount mode string length
 * @return Mode length in bytes
 */
uint8_t fuji_mount_get_mode_len(void);

/**
 * Copy mount mode from response to destination buffer
 * @param dest Destination buffer (must be at least mode_len bytes)
 * @param max_len Maximum bytes to copy
 * @return Actual bytes copied
 */
uint8_t fuji_mount_get_mode(uint8_t* dest, uint8_t max_len);

#endif /* FUJIBUS_FUJI_C_H */
