/**
 * FujiBus Disk Commands C Interface - Header File
 * 
 * Wire Device ID: 0xFC (FN_DEVICE_DISK)
 */

#ifndef FUJIBUS_DISK_C_H
#define FUJIBUS_DISK_C_H

#include <stdint.h>
#include <stdbool.h>

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
 * @param uri Pointer to NUL-terminated URI string
 * @return true on success
 */
bool fujibus_disk_mount(uint8_t slot, uint8_t flags, uint8_t* uri);

/**
 * Unmount a disk image
 * @param slot Drive slot (1-8)
 * @return true on success
 */
bool fujibus_disk_unmount(uint8_t slot);

/**
 * Read a sector
 * @param slot Drive slot (1-8)
 * @param lba Sector number
 * @param buf 256-byte buffer for data
 * @return true on success
 */
bool fujibus_disk_read_sector(uint8_t slot, uint16_t lba, uint8_t* buf);

/**
 * Write a sector
 * @param slot Drive slot (1-8)
 * @param lba Sector number
 * @param buf 256-byte buffer with data to write
 * @return true on success
 */
bool fujibus_disk_write_sector(uint8_t slot, uint16_t lba, uint8_t* buf);

/**
 * Get disk slot information
 * @param slot Drive slot (1-8)
 * @param info Pointer to DiskInfo struct to fill
 * @return true on success
 */
bool fujibus_disk_info(uint8_t slot, DiskInfo* info);

#endif /* FUJIBUS_DISK_C_H */
