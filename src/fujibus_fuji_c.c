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

/**
 * fujibus_get_mount_slot - Get mount record for a slot (FujiBus protocol)
 * 
 * Sends GetMount command to FujiNet for the specified slot.
 * Response format (bytes relative to buf[0]; after FujiBus hdr, status at [6]):
 *   [7]=slot echo, [8]=flags (bit0=enabled), [9]=uri_len, [10]=uri..., then mode...
 * 
 * Uses the current mount slot number
 * @return true on success, false on failure
 */
bool fujibus_get_mount_slot() {
    uint8_t *buf = fuji_data_buffer_ptr();

    /* Build GetMount request payload - just the slot index */
    buf[6] = *FUJI_DISK_SLOT;

    /* Send packet - GetMount has 1 byte payload */
    fujibus_send_packet(FN_DEVICE_FUJI, FUJI_CMD_GET_MOUNT, &buf[6], 1);
    
    if (fujibus_receive_packet() == 0) {
        return false;
    }
    
    /* Check descriptor: 1 param (status) and its value */
    if (buf[5] != 1 || buf[6] != 0) {
        return false;
    }
    
    return true;
}

/**
 * fujibus_set_mount_slot - Set mount record for a slot (FujiBus protocol)
 * 
 * Sends SetMount command to FujiNet to persist a mount entry.
 * Payload format: [slot][flags][uri_len][uri][mode_len][mode]
 * 
 * Uses global fuji_disk_slot for slot number.
 * Assumes the full URI (host + filename) is already in the PWS FS URI buffer
 * (fuji_fs_uri_ptr()) with length in FUJI_CURRENT_FS_LEN.
 * 
 * @return true on success, false on failure
 */
bool fujibus_set_mount_slot() {
    uint8_t slot;
    uint8_t uri_len;
    uint8_t mode_len;
    uint8_t i;
    uint8_t* tx;
    uint8_t* uri_ptr;
    
    tx = fuji_data_buffer_ptr();
    
    /* Get slot from global */
    slot = *FUJI_DISK_SLOT;
    
    /* Get URI from global */
    uri_ptr = fuji_fs_uri_ptr();
    uri_len = *FUJI_CURRENT_FS_LEN;
    
    /* Default mode is "r" (read-only) */
    mode_len = 1;
    
    /* Build SetMount payload at tx[6] */
    tx[6] = slot;              /* slot index */
    tx[7] = 0x01;              /* flags: bit0 = enabled */
    tx[8] = uri_len;           /* URI length */
    
    /* Copy URI */
    for (i = 0; i < uri_len; i++) {
        tx[9 + i] = uri_ptr[i];
    }
    
    /* Mode "r" */
    tx[9 + uri_len] = mode_len;       /* mode length */
    tx[9 + uri_len + 1] = 'r';        /* mode "r" */
    
    /* Total payload: slot(1) + flags(1) + uri_len(1) + uri + mode_len(1) + mode */
    /* = 3 + uri_len + 1 + mode_len = 4 + uri_len + mode_len */
    
    /* Send packet */
    fujibus_send_packet(FN_DEVICE_FUJI, FUJI_CMD_SET_MOUNT, &tx[6], 4 + uri_len + mode_len);
    
    if (fujibus_receive_packet() == 0) {
        return false;
    }
    
    /* Check descriptor: 1 param (status) and its value */
    if (tx[5] != 1 || tx[6] != 0) {
        return false;
    }
    
    return true;
}

