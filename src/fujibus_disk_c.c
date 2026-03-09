/**
 * FujiBus Disk Commands C Implementation for BBC Micro
 * 
 * Implements disk device commands using FujiBus protocol.
 * Uses fujibus_c functions for packet handling.
 * 
 * Wire Device ID: 0xFC (FN_DEVICE_DISK)
 * 
 * Commands:
 *   0x01 - Mount
 *   0x02 - Unmount
 *   0x03 - ReadSector
 *   0x04 - WriteSector
 *   0x05 - Info
 *   0x06 - ClearChanged
 *   0x07 - Create
 */

#include <stdint.h>
#include <stdbool.h>
#include "zp_overlay.h"
#include "fujibus_c.h"
#include "fujibus_disk_c.h"

/* ============================================================================
 * Constants
 * ============================================================================ */

#define FN_DEVICE_DISK         0xFC
#define FN_PROTOCOL_VERSION    1

#define DISK_CMD_MOUNT         0x01
#define DISK_CMD_UNMOUNT       0x02
#define DISK_CMD_READ_SECTOR   0x03
#define DISK_CMD_WRITE_SECTOR  0x04
#define DISK_CMD_INFO          0x05
#define DISK_CMD_CLEAR_CHANGED 0x06
#define DISK_CMD_CREATE        0x07

/* ============================================================================
 * Workspace variables (using ZP overlay)
 * ============================================================================ */

/* Disk slot (1-8) - stored in workspace */
#define fn_disk_slot         (ZP.aws_tmp[6])

/* Disk flags */
#define fn_disk_flags        (ZP.aws_tmp[7])

/* Current sector number for read/write */
#define fuji_current_sector  (ZP.pws_tmp[0])

/* Data buffer pointer */
#define data_ptr             (ZP.aws_tmp[8])

/* ============================================================================
 * Helper: Send request and receive response
 * Returns: packet length (0 = error)
 * ============================================================================ */

static uint8_t fujibus_disk_transaction(uint8_t payload_len) {
    uint8_t result;
    
    /* Send packet */
    fujibus_send_packet(FN_DEVICE_DISK, FUJI_TX_BUFFER[1], &FUJI_TX_BUFFER[FUJIBUS_HEADER_SIZE], payload_len);
    
    /* Receive response */
    result = fujibus_receive_packet();
    
    return result;
}

/* ============================================================================
 * fujibus_disk_mount - Mount a disk image
 * 
 * Input:
 *   slot - drive number (1-8)
 *   flags - bit0 = read-only
 *   uri - pointer to NUL-terminated URI string
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_mount(uint8_t slot, uint8_t flags, uint8_t* uri) {
    uint8_t uri_len;
    uint8_t i;
    uint8_t* tx;
    uint8_t resp_len;
    
    tx = FUJI_TX_BUFFER;
    
    /* Save parameters */
    fn_disk_slot = slot;
    fn_disk_flags = flags;
    
    /* Find URI length */
    uri_len = 0;
    while (uri[uri_len] != 0) {
        uri_len++;
    }
    
    /* Build payload in TX buffer */
    /* Payload: version(1) + slot(1) + flags(1) + typeOverride(1) + sectorSizeHint(2) + uriLen(2) + uri */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = slot;                    /* slot */
    tx[8] = flags;                    /* flags */
    tx[9] = 0;                       /* typeOverride = 0 (auto) */
    tx[10] = 0;                      /* sectorSizeHint low */
    tx[11] = 0;                      /* sectorSizeHint high */
    tx[12] = uri_len;                /* URI length low */
    tx[13] = 0;                      /* URI length high */
    
    /* Copy URI */
    for (i = 0; i < uri_len; i++) {
        tx[14 + i] = uri[i];
    }
    
    /* Payload length = 8 (fixed) + uri_len */
    /* Send and receive */
    resp_len = fujibus_disk_transaction(8 + uri_len);
    
    if (resp_len == 0) {
        return false;
    }
    
    /* Check response - byte at offset 7 (after header) should have bit 0 set */
    if ((FUJI_RX_BUFFER[7] & 0x01) == 0) {
        return false;
    }
    
    return true;
}

/* ============================================================================
 * fujibus_disk_unmount - Unmount a disk image
 * 
 * Input:
 *   slot - drive number (1-8)
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_unmount(uint8_t slot) {
    uint8_t* tx;
    uint8_t resp_len;
    
    tx = FUJI_TX_BUFFER;
    
    /* Save slot */
    fn_disk_slot = slot;
    
    /* Build payload */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = slot;                    /* slot */
    
    /* Payload length = 2 */
    resp_len = fujibus_disk_transaction(2);
    
    return (resp_len != 0);
}

/* ============================================================================
 * fujibus_disk_read_sector - Read a sector
 * 
 * Input:
 *   slot - drive number (1-8)
 *   lba - sector number (16-bit)
 *   buf - buffer for data (256 bytes)
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_read_sector(uint8_t slot, uint16_t lba, uint8_t* buf) {
    uint8_t* tx;
    uint8_t* rx;
    uint8_t resp_len;
    uint8_t data_len;
    uint8_t i;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Save slot */
    fn_disk_slot = slot;
    
    /* Build payload */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = slot;                    /* slot */
    tx[8] = (uint8_t)(lba & 0xFF);          /* LBA low */
    tx[9] = (uint8_t)((lba >> 8) & 0xFF);  /* LBA high */
    tx[10] = 0;                     /* LBA bits 16-23 */
    tx[11] = 0;                     /* LBA bits 24-31 */
    tx[12] = 0;                     /* maxBytes low (request 256) */
    tx[13] = 1;                     /* maxBytes high */
    
    /* Payload length = 8 */
    resp_len = fujibus_disk_transaction(8);
    
    if (resp_len == 0) {
        return false;
    }
    
    /* Check for error - flags at offset 7 */
    if (rx[7] != 0) {
        /* Flag bit 1 = truncated, we ignore for now */
        /* Just continue and copy data */
    }
    
    /* Get data length from response: offset 15-16 (after header + version + flags + res(2) + slot + lba(4)) */
    data_len = rx[16];
    /* Could also check high byte at rx[17] but we only support 256 */
    
    /* Copy data to buffer */
    /* Data starts at offset 17 (header is 6, payload starts at 6, data starts at 6 + 11 = 17) */
    for (i = 0; i < data_len; i++) {
        buf[i] = rx[17 + i];
    }
    
    return true;
}

/* ============================================================================
 * fujibus_disk_write_sector - Write a sector
 * 
 * Input:
 *   slot - drive number (1-8)
 *   lba - sector number (16-bit)
 *   buf - data to write (256 bytes)
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_write_sector(uint8_t slot, uint16_t lba, uint8_t* buf) {
    uint8_t* tx;
    uint8_t* rx;
    uint8_t resp_len;
    uint8_t i;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Save slot */
    fn_disk_slot = slot;
    
    /* Build payload */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = slot;                    /* slot */
    tx[8] = (uint8_t)(lba & 0xFF);          /* LBA low */
    tx[9] = (uint8_t)((lba >> 8) & 0xFF);  /* LBA high */
    tx[10] = 0;                     /* LBA bits 16-23 */
    tx[11] = 0;                     /* LBA bits 24-31 */
    tx[12] = 0;                     /* dataLen low = 256 */
    tx[13] = 1;                     /* dataLen high */
    
    /* Copy data */
    for (i = 0; i < 256; i++) {
        tx[14 + i] = buf[i];
    }
    
    /* Payload length = 8 + 256 = 264 */
    resp_len = fujibus_disk_transaction(264);
    
    if (resp_len == 0) {
        return false;
    }
    
    /* Check for error */
    if (rx[7] != 0) {
        return false;
    }
    
    return true;
}

/* ============================================================================
 * fujibus_disk_info - Get disk slot information
 * 
 * Input:
 *   slot - drive number (1-8)
 *   info - pointer to DiskInfo struct to fill
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_info(uint8_t slot, DiskInfo* info) {
    uint8_t* tx;
    uint8_t* rx;
    uint8_t resp_len;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Build payload */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = slot;                    /* slot */
    
    /* Payload length = 2 */
    resp_len = fujibus_disk_transaction(2);
    
    if (resp_len == 0) {
        return false;
    }
    
    /* Parse response */
    /* Response: version(1) + flags(1) + reserved(2) + slot(1) + type(1) + sectorSize(2) + sectorCount(4) + lastError(1) */
    info->flags = rx[7];
    info->type = rx[9];
    info->sectorSize = (uint16_t)rx[10] | ((uint16_t)rx[11] << 8);
    info->sectorCount = (uint32_t)rx[12] | ((uint32_t)rx[13] << 8) | ((uint32_t)rx[14] << 16) | ((uint32_t)rx[15] << 24);
    info->lastError = rx[16];
    
    return true;
}
