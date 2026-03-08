/**
 * FujiBus Protocol Implementation in C for BBC Micro
 * 
 * Implements SLIP framing and FujiBus packet handling
 * Compatible with fujinet-nio FujiBus protocol
 * 
 * Based on:
 * - py/fujinet_tools/fujibus.py
 * - Original fujibus.s (commented out)
 */

#include <stdint.h>
#include <stdbool.h>
#include "zp_overlay.h"
#include "calc_checksum.h"
#include "fujibus_c.h"

/* ============================================================================
 * Constants
 * ============================================================================ */

/* SLIP protocol constants */
#define FUJIBUS_SLIP_END       0xC0
#define FUJIBUS_SLIP_ESCAPE    0xDB
#define FUJIBUS_SLIP_ESC_END   0xDC
#define FUJIBUS_SLIP_ESC_ESC   0xDD

/* FujiBus protocol constants */
#define FUJIBUS_HEADER_SIZE    6       /* device(1) + command(1) + length(2) + checksum(1) + descr(1) */
#define FUJIBUS_MAX_SLIP_SIZE  640     /* Max SLIP encoded packet size */
#define FUJIBUS_MAX_PACKET     320     /* Max raw packet size */

/* Buffer addresses (from os.s) */
/* fuji_workspace = $1000 */
#define FUJI_TX_BUFFER     ((uint8_t*)0x12A0)  /* fuji_workspace + $02A0 */
#define FUJI_RX_BUFFER     ((uint8_t*)0x1300)  /* fuji_workspace + $0300 */
#define FUJI_SLIP_BUFFER   FUJI_RX_BUFFER       /* Reuse RX buffer for SLIP encoding */

/* ============================================================================
 * Local variables - stored in zeropage workspace
 * ============================================================================ */

/* Buffer lengths - stored in zeropage (using ZP overlay) */
/* aws_tmp[14-15] = tx_len, tx_len_hi (0xBE-0xBF) */
/* aws_tmp[16-17] = rx_len, rx_len_hi (0xC0-0xC1) */

#define fujibus_tx_len       (ZP.aws_tmp[14])
#define fujibus_tx_len_hi    (ZP.aws_tmp[15])
#define fujibus_rx_len       (ZP.aws_tmp[16])
#define fujibus_rx_len_hi    (ZP.aws_tmp[17])

/* ============================================================================
 * External ASM functions
 * ============================================================================ */

/* Serial I/O - parameters in aws_tmp00/01 (buffer) and aws_tmp02/03 (length) */
extern void write_serial_data(void);
extern void read_serial_data(void);

/* ============================================================================
 * Helper functions for ASM interface
 * ============================================================================ */

/**
 * Call ASM write_serial_data function
 * Sets up zeropage parameters before calling
 */
static void call_write_serial(uint8_t* buffer, uint16_t len) {
    /* Set buffer pointer in aws_tmp00/01 */
    ZP.aws_tmp[0] = (uint8_t)((uint16_t)buffer & 0xFF);
    ZP.aws_tmp[1] = (uint8_t)(((uint16_t)buffer >> 8) & 0xFF);
    
    /* Set length in aws_tmp02/03 */
    ZP.aws_tmp[2] = (uint8_t)(len & 0xFF);
    ZP.aws_tmp[3] = (uint8_t)((len >> 8) & 0xFF);
    
    /* Call ASM function */
    write_serial_data();
}

/**
 * Call ASM read_serial_data function
 * Sets up zeropage parameters before calling
 */
static void call_read_serial(uint8_t* buffer, uint16_t max_len) {
    /* Set buffer pointer in aws_tmp00/01 */
    ZP.aws_tmp[0] = (uint8_t)((uint16_t)buffer & 0xFF);
    ZP.aws_tmp[1] = (uint8_t)(((uint16_t)buffer >> 8) & 0xFF);
    
    /* Set max length in aws_tmp02/03 */
    ZP.aws_tmp[2] = (uint8_t)(max_len & 0xFF);
    ZP.aws_tmp[3] = (uint8_t)((max_len >> 8) & 0xFF);
    
    /* Call ASM function */
    read_serial_data();
    
    /* Read bytes read from aws_tmp04/05 (if available) */
    /* For now, assume max_len was used */
}

/* ============================================================================
 * SLIP Encoding
 * ============================================================================ */

/**
 * Encode data with SLIP framing
 * 
 * Input:
 *   input - pointer to data to encode
 *   len   - length of input data
 * 
 * Output:
 *   Returns length of SLIP-encoded data (stored in FUJI_SLIP_BUFFER)
 */
uint16_t fujibus_slip_encode(uint8_t* input, uint16_t len) {
    uint16_t out_idx = 0;
    uint16_t in_idx = 0;
    
    /* Start with END marker */
    FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_END;
    
    /* Encode each byte */
    while (in_idx < len) {
        uint8_t b = input[in_idx++];
        
        if (b == FUJIBUS_SLIP_END) {
            /* Escape END byte */
            FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_ESCAPE;
            FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_ESC_END;
        } else if (b == FUJIBUS_SLIP_ESCAPE) {
            /* Escape ESCAPE byte */
            FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_ESCAPE;
            FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_ESC_ESC;
        } else {
            /* Normal byte */
            FUJI_SLIP_BUFFER[out_idx++] = b;
        }
    }
    
    /* End with END marker */
    FUJI_SLIP_BUFFER[out_idx++] = FUJIBUS_SLIP_END;
    
    /* Store output length */
    fujibus_tx_len = (uint8_t)(out_idx & 0xFF);
    fujibus_tx_len_hi = (uint8_t)((out_idx >> 8) & 0xFF);
    
    return out_idx;
}

/* ============================================================================
 * SLIP Decoding
 * ============================================================================ */

/**
 * Decode SLIP-framed data
 * 
 * Input:
 *   input - pointer to SLIP-encoded data
 *   len   - length of encoded data
 * 
 * Output:
 *   Returns length of decoded data (stored in FUJI_RX_BUFFER)
 *   Returns 0 on error (invalid frame)
 */
uint16_t fujibus_slip_decode(uint8_t* input, uint16_t len) {
    uint16_t out_idx = 0;
    uint16_t in_idx = 0;
    uint8_t b;
    uint8_t esc;
    
    /* Check for valid frame (must start and end with END) */
    if (len < 2 || input[0] != FUJIBUS_SLIP_END || input[len-1] != FUJIBUS_SLIP_END) {
        return 0;
    }
    
    /* Skip leading END marker */
    in_idx = 1;
    
    /* Decode until trailing END */
    while (in_idx < len - 1) {
        b = input[in_idx++];
        
        if (b == FUJIBUS_SLIP_ESCAPE) {
            /* Handle escape sequence */
            if (in_idx >= len - 1) {
                break;  /* Incomplete escape */
            }
            
            esc = input[in_idx++];
            
            if (esc == FUJIBUS_SLIP_ESC_END) {
                FUJI_RX_BUFFER[out_idx++] = FUJIBUS_SLIP_END;
            } else if (esc == FUJIBUS_SLIP_ESC_ESC) {
                FUJI_RX_BUFFER[out_idx++] = FUJIBUS_SLIP_ESCAPE;
            } else {
                /* Unknown escape - keep original byte (matches Python behavior) */
                FUJI_RX_BUFFER[out_idx++] = b;
            }
        } else if (b == FUJIBUS_SLIP_END) {
            /* End of frame */
            break;
        } else {
            /* Normal byte */
            FUJI_RX_BUFFER[out_idx++] = b;
        }
    }
    
    /* Store output length */
    fujibus_rx_len = (uint8_t)(out_idx & 0xFF);
    fujibus_rx_len_hi = (uint8_t)((out_idx >> 8) & 0xFF);
    
    return out_idx;
}

/* ============================================================================
 * Packet Building
 * ============================================================================ */

/**
 * Build a FujiBus packet
 * 
 * Input:
 *   device   - device ID
 *   command  - command byte
 *   payload  - pointer to payload data
 *   paylen   - payload length
 * 
 * Output:
 *   Returns total packet length (stored in FUJI_TX_BUFFER)
 *   Packet is ready for SLIP encoding
 */
uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen) {
    uint16_t total_len;
    uint8_t i;
    
    /* Calculate total length = header(6) + payload */
    total_len = FUJIBUS_HEADER_SIZE + paylen;
    
    /* Build header */
    FUJI_TX_BUFFER[0] = device;              /* Device ID */
    FUJI_TX_BUFFER[1] = command;             /* Command */
    FUJI_TX_BUFFER[2] = (uint8_t)(total_len & 0xFF);        /* Length low */
    FUJI_TX_BUFFER[3] = (uint8_t)((total_len >> 8) & 0xFF); /* Length high */
    FUJI_TX_BUFFER[4] = 0;                   /* Checksum placeholder (will be calculated) */
    FUJI_TX_BUFFER[5] = 0;                   /* Descriptor (0 for simple packets) */
    
    /* Copy payload */
    for (i = 0; i < paylen; i++) {
        FUJI_TX_BUFFER[FUJIBUS_HEADER_SIZE + i] = payload[i];
    }
    
    /* Calculate and store checksum */
    /* The checksum function expects buffer pointer and length */
    /* We need to set checksum byte to 0 before calculating */
    FUJI_TX_BUFFER[4] = 0;
    
    /* Calculate checksum over the entire packet */
    FUJI_TX_BUFFER[4] = calc_checksum(FUJI_TX_BUFFER, total_len);
    
    /* Store packet length */
    fujibus_tx_len = (uint8_t)(total_len & 0xFF);
    fujibus_tx_len_hi = (uint8_t)((total_len >> 8) & 0xFF);
    
    return total_len;
}

/* ============================================================================
 * Packet Sending
 * ============================================================================ */

/**
 * Send a FujiBus packet via serial
 * 
 * Input:
 *   device   - device ID
 *   command  - command byte
 *   payload  - pointer to payload data
 *   paylen   - payload length
 * 
 * Output:
 *   Returns true on success, false on error
 */
bool fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen) {
    uint16_t pkt_len;
    uint16_t slip_len;
    
    /* Build the packet */
    pkt_len = fujibus_build_packet(device, command, payload, paylen);
    
    /* SLIP encode */
    slip_len = fujibus_slip_encode(FUJI_TX_BUFFER, pkt_len);
    
    /* Send via serial */
    call_write_serial(FUJI_SLIP_BUFFER, slip_len);
    
    return true;
}

/* ============================================================================
 * Packet Receiving
 * ============================================================================ */

/**
 * Receive a FujiBus packet via serial
 * 
 * Input:
 *   max_len - maximum length to read
 * 
 * Output:
 *   Returns length of received packet (in FUJI_RX_BUFFER)
 *   Returns 0 on error
 * 
 * Note: This is a simplified version. For full implementation,
 *       would need to handle timeouts and partial reads.
 */
uint16_t fujibus_receive_packet(uint16_t max_len) {
    uint16_t slip_len;
    uint16_t decoded_len;
    uint8_t checksum_received;
    uint8_t checksum_computed;
    
    /* Limit max read size */
    if (max_len > FUJIBUS_MAX_SLIP_SIZE) {
        max_len = FUJIBUS_MAX_SLIP_SIZE;
    }
    
    /* Read from serial into SLIP buffer */
    call_read_serial(FUJI_SLIP_BUFFER, max_len);
    
    /* Get actual bytes read */
    slip_len = fujibus_rx_len;
    if (slip_len == 0) {
        slip_len = max_len;  /* Use max as fallback */
    }
    
    /* SLIP decode */
    decoded_len = fujibus_slip_decode(FUJI_SLIP_BUFFER, slip_len);
    
    /* Validate minimum size */
    if (decoded_len < FUJIBUS_HEADER_SIZE) {
        return 0;
    }
    
    /* Validate checksum */
    checksum_received = FUJI_RX_BUFFER[4];
    
    /* Zero checksum byte for calculation */
    FUJI_RX_BUFFER[4] = 0;
    
    /* Calculate checksum over entire packet */
    checksum_computed = calc_checksum(FUJI_RX_BUFFER, decoded_len);
    
    /* Restore checksum byte */
    FUJI_RX_BUFFER[4] = checksum_received;
    
    /* Verify checksum matches */
    if (checksum_received != checksum_computed) {
        return 0;  /* Checksum mismatch */
    }
    
    return decoded_len;
}

/**
 * Get received packet device ID
 */
uint8_t fujibus_get_device(void) {
    return FUJI_RX_BUFFER[0];
}

/**
 * Get received packet command
 */
uint8_t fujibus_get_command(void) {
    return FUJI_RX_BUFFER[1];
}

/**
 * Get received packet length
 */
uint16_t fujibus_get_length(void) {
    return (uint16_t)FUJI_RX_BUFFER[2] | ((uint16_t)FUJI_RX_BUFFER[3] << 8);
}

/**
 * Get pointer to received packet payload
 */
uint8_t* fujibus_get_payload(void) {
    return &FUJI_RX_BUFFER[FUJIBUS_HEADER_SIZE];
}

/**
 * Get received packet payload length
 */
uint8_t fujibus_get_payload_length(void) {
    uint16_t total_len = fujibus_get_length();
    if (total_len < FUJIBUS_HEADER_SIZE) {
        return 0;
    }
    return (uint8_t)(total_len - FUJIBUS_HEADER_SIZE);
}
