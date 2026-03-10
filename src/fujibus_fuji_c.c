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
 * fuji_get_mount_slot - Get mount record for a slot
 * 
 * Sends GetMount command to FujiNet for the specified slot.
 * Response format (after FujiBus header and status param):
 *   [flags][uri_len][uri...][mode_len][mode...]
 * 
 * Uses the current mount slot number
 * @return true on success, false on failure
 */
bool fuji_get_mount_slot() {
    /* Build GetMount request payload - just the slot index */
    FUJI_TX_BUFFER[6] = *FUJI_DISK_SLOT;

    /* Send packet - GetMount has 1 byte payload */
    fujibus_send_packet(FN_DEVICE_FUJI, FUJI_CMD_GET_MOUNT, &FUJI_TX_BUFFER[6], 1);
    
    if (fujibus_receive_packet() == 0) {
        return false;
    }
    
    /* Check descriptor: 1 param (status) and its value */
    if (FUJI_RX_BUFFER[5] != 1 || FUJI_RX_BUFFER[6] != 0) {
        return false;
    }
    
    return true;
}

