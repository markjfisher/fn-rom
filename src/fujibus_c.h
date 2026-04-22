/**
 * FujiBus Protocol C Interface - Header File
 * 
 * Optimized for ROM - minimal overhead, uses constants.
 */

#ifndef FUJIBUS_C_H
#define FUJIBUS_C_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * Constants
 * ============================================================================ */

#define CURRENT_DRV              ((uint8_t*)0xCD)
#define aws_tmp08                (*(uint8_t*)0xB8)

#define FUJI_WORKSPACE           ((uint8_t*)0x1000)

#define FUJI_FILENAME_BUFFER     ((uint8_t*)0x1000)
#define FUJI_STATIC_WORKSPACE    ((uint8_t*)0x10C0)


//////////////////////////////////////////////////////////////////////////
// LOCATIONS WITHIN 1000-10FF
//////////////////////////////////////////////////////////////////////////

/* Current mount slot index */
#define FUJI_DISK_TABLE_INDEX    ((uint8_t*)0x10C7)

/* Error flag general purpose*/
#define FUJI_ERROR_FLAG          ((uint8_t*)0x10D9)
/* FujiNet drive-to-disk mapping (4 bytes: drives 0-3) */
#define FUJI_DRIVE_DISK_MAP      ((uint8_t*)0x10D9)

#define fuji_current_sector      ((uint8_t*)0x10E5)

#define FUJI_CURRENT_FS_LEN      ((uint8_t*)0x10E7)

#define FUJI_CURRENT_DIR_LEN     ((uint8_t*)0x10E8)

#define FUJI_CURRENT_MOUNT_SLOT  ((uint8_t*)0x10E9)

#define FUJI_DISK_SLOT           ((uint8_t*)0x10EB)  /* fuji_disk_slot - current slot, 1-based */
#define FUJI_DISK_FLAGS          ((uint8_t*)0x10EC)  /* fuji_disk_flags */

#define FUJI_CURRENT_HOST_LEN    ((uint8_t*)0x10ED)

/* Filename length (used by param parsing) */
#define FUJI_FILENAME_LEN        ((uint8_t*)0x10EF)


//////////////////////////////////////////////////////////////////////////
// BUFFERS
//////////////////////////////////////////////////////////////////////////

// THESE ARE WRONG - THEY INTERFERE WITH IO BUFFERS
// See page 111 of the Advanced Disk User Guide.

/* Resolved host URI (max 80 bytes); directory path is a suffix per ResolvePath lengths */
#define FUJI_CURRENT_HOST_URI    ((uint8_t*)0x11B0)

/* FS URI scratch (e.g. *FIN) in PWS after the packet buffer — see FUJI_FS_URI_OFFSET */
#define FUJI_FS_URI_BUFFER_SIZE  80

extern uint8_t* fuji_data_buffer_ptr(void);
extern uint8_t* fuji_fs_uri_ptr(void);
extern uint8_t* fuji_dir_path_ptr(void);



/* FileDevice (0xFE) */
#define FN_DEVICE_FILE           0xFE
#define FILE_CMD_RESOLVE_PATH    0x05

// #define SLIP_END                 0xC0
// #define SLIP_ESCAPE              0xDB
// #define SLIP_ESC_END             0xDC
// #define SLIP_ESC_ESC             0xDD

/* FujiDevice (0x70) - FujiNet device */
#define FN_DEVICE_FUJI           0x70
#define FUJI_CMD_GET_MOUNT       0xFB
#define FUJI_CMD_SET_MOUNT       0xFC


// #define FUJIBUS_HEADER_SIZE      6

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * SLIP encode to SLIP buffer
 * @param src Source data pointer
 * @param len Source data length
 * @return Encoded length
 */
uint16_t fujibus_slip_encode(uint8_t* src, uint16_t len);

/**
 * SLIP decode from SLIP buffer
 * @param enc_len Encoded data length
 * @return Decoded length, 0 on error
 */
uint16_t fujibus_slip_decode(uint16_t enc_len);

/**
 * Build FujiBus packet in TX buffer
 * @param device Device ID
 * @param command Command byte
 * @param payload Payload pointer
 * @param paylen Payload length
 * @return Total packet length
 */
uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen);

/**
 * Send FujiBus packet via serial
 * @param device Device ID
 * @param command Command byte
 * @param payload Payload pointer
 * @param paylen Payload length
 */
void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen);

/**
 * Receive FujiBus packet into RX buffer
 * @return Packet length (0 = error)
 */
uint16_t fujibus_receive_packet(void);

/* Accessor macros - inline for zero overhead */
// #define fujibus_get_device()         (FUJI_DATA_BUFFER[0])
// #define fujibus_get_command()        (FUJI_DATA_BUFFER[1])
// #define fujibus_get_length()         (FUJI_DATA_BUFFER[2])
// #define fujibus_get_payload()        (&FUJI_DATA_BUFFER[FUJIBUS_HEADER_SIZE])

#endif /* FUJIBUS_C_H */
