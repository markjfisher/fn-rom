/**
 * FujiBus FujiDevice C Interface - Implementation
 * 
 * Implements functions for interacting with FujiDevice (FujiNet)
 * Mount table operations via GetMount command.
 */

#include <stdint.h>
#include <stdbool.h>
#include "fujibus_c.h"
#include "fujibus_fuji_c.h"

/* ============================================================================
 * Local variables to store mount response data
 * ============================================================================ */

/* Stored mount response data */
static uint8_t g_mount_flags;
static uint8_t g_mount_uri_len;
static uint8_t g_mount_mode_len;

/**
 * fuji_get_mount_slot - Get mount record for a slot
 * 
 * Sends GetMount command to FujiNet for the specified slot.
 * Response format (after FujiBus header and status param):
 *   [flags][uri_len][uri...][mode_len][mode...]
 * 
 * @param slot Slot index (0-7)
 * @return true on success, false on failure
 */
bool fuji_get_mount_slot(uint8_t slot) {
    uint8_t* tx;
    uint8_t* rx;
    uint16_t resp_len;
    uint8_t uri_len;
    uint8_t mode_len;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Build GetMount request payload - just the slot index */
    tx[6] = slot;  /* Slot index */
    
    /* Send packet - GetMount has 1 byte payload */
    fujibus_send_packet(FN_DEVICE_FUJI, FUJI_CMD_GET_MOUNT, &tx[6], 1);
    
    /* Receive response */
    resp_len = fujibus_receive_packet();
    
    if (resp_len == 0) {
        return false;
    }
    
    /* FujiBus response structure: */
    /* rx[0-4]: header (device, cmd, length lo/hi, checksum) */
    /* rx[5]: descr (0x01 = 1 param following = status) */
    /* rx[6]: status param (0x00 for success) */
    /* rx[7]: payload starts here (flags) */
    
    /* Check descriptor: 1 param (status) */
    if (rx[5] != 1) {
        return false;
    }
    
    /* Check status: 0 = success */
    if (rx[6] != 0) {
        return false;
    }
    
    /* Parse mount record from response */
    /* rx[7]: flags (bit 0 = enabled) */
    /* rx[8]: uri_len */
    /* rx[9...]: uri */
    /* After uri: mode_len, then mode */
    
    g_mount_flags = rx[7];
    g_mount_uri_len = rx[8];
    
    /* Calculate mode_len: total_payload - flags(1) - uri_len(1) - uri */
    /* payload starts at rx[7], so we need to find mode_len position */
    uri_len = g_mount_uri_len;
    g_mount_mode_len = rx[7 + 1 + 1 + uri_len];  /* flags + uri_len + uri = mode_len position */
    
    return true;
}

/**
 * Check if mount slot is enabled
 * Must be called after fuji_get_mount_slot() returns true
 * @return true if slot is enabled and has a URI
 */
bool fuji_mount_slot_enabled(void) {
    /* Bit 0 of flags indicates enabled */
    return (g_mount_flags & 0x01) != 0 && g_mount_uri_len > 0;
}

/**
 * Get URI length from last mount response
 * @return URI length in bytes
 */
uint8_t fuji_mount_get_uri_len(void) {
    return g_mount_uri_len;
}

/**
 * Copy URI from mount response to destination buffer
 * URI starts at rx[9] (after header + status + flags + uri_len)
 * @param dest Destination buffer (must be at least uri_len bytes)
 * @param max_len Maximum bytes to copy
 * @return Actual bytes copied
 */
uint8_t fuji_mount_get_uri(uint8_t* dest, uint8_t max_len) {
    uint8_t* rx;
    uint8_t i;
    uint8_t len;
    
    rx = FUJI_RX_BUFFER;
    
    /* URI starts at rx[9]: header(6) + descr(1) + status(1) + flags(1) = rx[9] */
    /* Actually: rx[7] = flags, rx[8] = uri_len, so uri starts at rx[9] */
    len = g_mount_uri_len;
    if (len > max_len) {
        len = max_len;
    }
    
    for (i = 0; i < len; i++) {
        dest[i] = rx[9 + i];
    }
    
    return len;
}

/**
 * Get mount mode string length
 * @return Mode length in bytes
 */
uint8_t fuji_mount_get_mode_len(void) {
    return g_mount_mode_len;
}

/**
 * Copy mount mode from response to destination buffer
 * @param dest Destination buffer (must be at least mode_len bytes)
 * @param max_len Maximum bytes to copy
 * @return Actual bytes copied
 */
uint8_t fuji_mount_get_mode(uint8_t* dest, uint8_t max_len) {
    uint8_t* rx;
    uint8_t i;
    uint8_t len;
    uint8_t uri_len;
    
    rx = FUJI_RX_BUFFER;
    
    /* Find mode position: after header(6) + descr(1) + status(1) + flags(1) + uri_len(1) + uri */
    /* = rx[7] + 1 + uri_len = rx[8 + uri_len] is mode_len, mode starts at rx[9 + uri_len] */
    uri_len = g_mount_uri_len;
    len = g_mount_mode_len;
    
    if (len > max_len) {
        len = max_len;
    }
    
    for (i = 0; i < len; i++) {
        dest[i] = rx[9 + uri_len + i];
    }
    
    return len;
}
