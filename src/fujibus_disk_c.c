/**
 * FujiBus Disk Commands C Implementation for BBC Micro
 * 
 * Implements disk device commands using FujiBus protocol.
 * Uses fujibus_c functions for packet handling.
 * 
 * Wire Device ID: 0xFC (FN_DEVICE_DISK)
 * Also handles FileDevice (0xFE) commands like ResolvePath
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
#include "fujibus_c.h"
#include "fujibus_disk_c.h"

/* ============================================================================
 * Constants
 * ============================================================================ */

#define FN_DEVICE_DISK         0xFC
#define FN_DEVICE_FILE         0xFE
#define FN_PROTOCOL_VERSION    1

#define DISK_CMD_MOUNT         0x01
#define DISK_CMD_UNMOUNT       0x02
#define DISK_CMD_READ_SECTOR   0x03
#define DISK_CMD_WRITE_SECTOR  0x04
#define DISK_CMD_INFO          0x05
#define DISK_CMD_CLEAR_CHANGED 0x06
#define DISK_CMD_CREATE        0x07

#define FILE_CMD_RESOLVE_PATH  0x05
#define FILEPROTO_VERSION      1

/* ============================================================================
 * Workspace variables (using persistent FujiNet workspace)
 * ============================================================================ */

/* Disk slot (1-8) - stored in persistent workspace at 0x10EC */
#define fn_disk_slot           (*FUJI_DISK_SLOT)

/* Disk flags - stored in persistent workspace at 0x10ED */
#define fn_disk_flags          (*FUJI_DISK_FLAGS)

/* ============================================================================
 * Helper: Send request and receive response
 * Returns: packet length (0 = error)
 * ============================================================================ */

static uint16_t fujibus_disk_transaction(uint16_t payload_len) {
    uint16_t result;
    
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
// bool fujibus_disk_mount(uint8_t slot, uint8_t flags, uint8_t uri_len, uint8_t* uri) {
bool fujibus_disk_mount(uint8_t flags) {
    uint16_t i;
    uint8_t* tx;
    uint16_t resp_len;
    
    tx = FUJI_TX_BUFFER;
    
    /* Save parameters */
    fn_disk_slot = *FUJI_DISK_SLOT;  /* Use FUJI_DISK_SLOT (0x10EC) - same as FMOUNT uses */
    fn_disk_flags = flags;
    
    /* Build payload in TX buffer */
    tx[1] = DISK_CMD_MOUNT_DISK;

    /* Payload: version(1) + slot(1) + flags(1) + typeOverride(1) + sectorSizeHint(2) + uriLen(2) + uri */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = *FUJI_DISK_SLOT + 1;  /* slot - convert 0-based to 1-based for DiskDevice */
    tx[8] = flags;                   /* flags */
    tx[9] = 0;                       /* typeOverride = 0 (auto) */
    tx[10] = 0;                      /* sectorSizeHint low */
    tx[11] = 0;                      /* sectorSizeHint high */
    tx[12] = *FUJI_CURRENT_FS_LEN;         /* URI length low */
    tx[13] = 0;                      /* URI length high */
    
    /* Copy URI */
    for (i = 0; i < (*FUJI_CURRENT_FS_LEN); i++) {
        tx[14 + i] = FUJI_CURRENT_FS_URI[i];
    }
    
    /* Payload length = 8 (fixed) + uri_len */
    /* Send and receive */
    resp_len = fujibus_disk_transaction(8 + (*FUJI_CURRENT_FS_LEN));
    
    if (resp_len == 0) {
        return false;
    }
    
    /* Check response status */
    if (FUJI_RX_BUFFER[5] != 1 || FUJI_RX_BUFFER[6] != 0) {
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
    uint16_t resp_len;
    
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
 * Uses global state:
 *   slot - from fuji_disk_slot (FUJI_DISK_SLOT)
 *   lba - from fuji_current_sector (2 bytes)
 *   buf - from data_ptr
 * 
 * Output:
 *   Returns true on success, false on error
 * ============================================================================ */
bool fujibus_disk_read_sector(void) {
    uint8_t* tx;
    uint8_t* rx;
    uint16_t resp_len;
    uint16_t data_len;
    uint16_t i;
    uint8_t* buf;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    
    /* Get buffer address from data_ptr */
    buf = *data_ptr;
    
    /* Get slot from fuji_disk_slot */
    fn_disk_slot = *FUJI_DISK_SLOT;
    
    /* Build payload */
    tx[6] = FN_PROTOCOL_VERSION;     /* version */
    tx[7] = fn_disk_slot + 1;      /* slot - convert 0-based to 1-based for DiskDevice */
    tx[8] = fuji_current_sector;           /* LBA low */
    tx[9] = fuji_current_sector+1;         /* LBA high */
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
    uint16_t resp_len;
    uint16_t i;
    
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
    uint16_t resp_len;
    
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

/* ============================================================================
 * fujibus_resolve_path - Resolve path using FileDevice (FujiBus protocol)
 * 
 * Sends ResolvePath command to FujiNet FileDevice to canonicalize a URI.
 * 
 * Uses:
 *   FUJI_TX_BUFFER[6] - request payload built here
 *   FUJI_RX_BUFFER - response parsed here
 * 
 * Input:
 *   FUJI_CURRENT_HOST_URI - base URI
 *   FUJI_CURRENT_HOST_LEN - base URI length
 * 
 * Output:
 *   FUJI_CURRENT_HOST_URI - resolved URI
 *   FUJI_CURRENT_HOST_LEN - resolved URI length
 *   FUJI_CURRENT_DIR_PATH - display path
 *   FUJI_CURRENT_DIR_LEN - display path length
 * 
 * Returns: true on success, false on error
 * ============================================================================ */

bool fujibus_resolve_path(void) {
    uint16_t resp_len;
    uint8_t i;
    uint16_t uri_end;
    uint8_t dir_len;
    uint8_t* tx;
    uint8_t* rx;
    uint8_t uri_len;
    
    tx = FUJI_TX_BUFFER;
    rx = FUJI_RX_BUFFER;
    uri_len = *FUJI_CURRENT_HOST_LEN;
    
    /* Build ResolvePath request payload */
    /* Payload: version(1) + base_uri_len(2) + base_uri + arg_len(2) + arg(0) */    
    tx[6] = FILEPROTO_VERSION;           /* version */
    
    /* base_uri_len */
    tx[7] = uri_len;
    tx[8] = 0;
    
    /* base_uri */
    for (i = 0; i < uri_len; i++) {
        tx[9 + i] = FUJI_CURRENT_HOST_URI[i];
    }
    
    /* arg_len = 0 */
    tx[9 + uri_len] = 0;
    tx[10 + uri_len] = 0;
    
    /* Send packet to FileDevice */
    fujibus_send_packet(FN_DEVICE_FILE, FILE_CMD_RESOLVE_PATH, &tx[6], 5 + uri_len);
    
    /* Receive response */
    resp_len = fujibus_receive_packet();
    
    if (resp_len == 0) {
        return false;
    }
    
    /* FujiBus response structure: */
    /* rx[0-4]: header (device, cmd, length lo/hi, checksum) */
    /* rx[5]: descr (0x01 = 1 param following = status) */
    /* rx[6]: status param (from addParamU8) = 0x00 for success */
    /* rx[7]: payload version */
    /* rx[8]: payload flags */
    /* rx[9-10]: payload reserved */
    /* rx[11-12]: uri_len */
    /* rx[13]: uri starts here */
    /* After uri: dir_len (2 bytes), then dir */
    
    /* Check descriptor: 1 param (status) and its value */
    if (rx[5] != 1 || rx[6] != 0 || rx[7] != FILEPROTO_VERSION) {
        return false;
    }

    /* Get resolved_uri_len from response */
    *FUJI_CURRENT_HOST_LEN = rx[11];  /* Low byte of uri_len */
    
    /* Copy resolved_uri to fuji_current_fs_uri */
    /* URI starts at rx[13] (after version, flags, reserved, uri_len) */
    for (i = 0; i < (*FUJI_CURRENT_HOST_LEN); i++) {
        FUJI_CURRENT_HOST_URI[i] = rx[13 + i];
    }
    
    /* Get display_path_len */
    /* uri ends at rx[13 - 1 + uri_len], dir_len starts at rx[13 + uri_len] */
    uri_end = 12 + (*FUJI_CURRENT_HOST_LEN);
    dir_len = rx[uri_end + 1];  /* Low byte of dir_len */
    
    /* Copy display_path to fuji_current_dir_path */
    for (i = 0; i < dir_len; i++) {
        FUJI_CURRENT_DIR_PATH[i] = rx[uri_end + 3 + i];
    }
    *FUJI_CURRENT_DIR_LEN = dir_len;
    
    return true;
}
