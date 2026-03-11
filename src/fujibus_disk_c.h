/**
 * FujiBus Disk Commands C Interface - Header File
 * 
 * Wire Device ID: 0xFC (FN_DEVICE_DISK)
 */

#ifndef FUJIBUS_DISK_C_H
#define FUJIBUS_DISK_C_H

#include <stdint.h>
#include <stdbool.h>

// disk_device commands
#define DISK_CMD_MOUNT_DISK     1


/* ============================================================================
 * Structures
 * ============================================================================ */

/**
 * Disk info structure - filled by fujibus_disk_info
 */
typedef struct {
    uint8_t flags;        /* bit0=inserted, bit1=readOnly, bit2=dirty, bit3=changed */
    uint8_t type;        /* disk image type */
    uint16_t sectorSize; /* bytes per sector */
    uint32_t sectorCount; /* total sectors */
    uint8_t lastError;   /* last error code */
} DiskInfo;

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * Mount a disk image
 * @param slot Drive slot (1-8)
 * @param flags Bit0 = read-only
 * @param uri_len length of uri
 * @param uri Pointer to URI string (not nul terminated, keep lengths separate)
 * @return true on success
 */
// bool fujibus_disk_mount(uint8_t slot, uint8_t flags, uint8_t uri_len, uint8_t* uri);

bool fujibus_disk_mount(uint8_t flags);

/**
 * Unmount a disk image
 * @param slot Drive slot (1-8)
 * @return true on success
 */
bool fujibus_disk_unmount(uint8_t slot);

/**
 * Read a sector, values are taken from workspace state
 * @return true on success
 */
bool fujibus_disk_read_sector(void);

/**
 * Write a sector
 * @param slot Drive slot (1-8)
 * @param lba Sector number
 * @param buf 256-byte buffer with data to write
 * @return true on success
 */
bool fujibus_disk_write_sector(uint8_t slot, uint16_t lba, uint8_t* buf);

/**
 * Write a sector, values are taken from workspace state
 * @return true on success
 */
bool fujibus_disk_write_sector_current(void);

/**
 * Get disk slot information
 * @param slot Drive slot (1-8)
 * @param info Pointer to DiskInfo struct to fill
 * @return true on success
 */
bool fujibus_disk_info(uint8_t slot, DiskInfo* info);

/**
 * fujibus_resolve_path - Resolve path using FileDevice (FujiBus protocol)
 * 
 * Sends ResolvePath command to FujiNet FileDevice to canonicalize a URI.
 * Uses FUJI_CURRENT_HOST_URI/LEN for input and output.
 * 
 * @return true on success, false on error
 */
bool fujibus_resolve_path(void);

static uint16_t fujibus_disk_transaction(uint8_t command, uint16_t payload_len);

#endif /* FUJIBUS_DISK_C_H */
