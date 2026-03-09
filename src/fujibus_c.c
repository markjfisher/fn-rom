/**
 * FujiBus Protocol Implementation in C for BBC Micro
 * 
 * Optimized for ROM - minimal overhead, uses constants where possible.
 * Implements SLIP framing and FujiBus packet handling.
 */

#include <stdint.h>
#include <stdbool.h>
#include "zp_overlay.h"
#include "calc_checksum.h"
#include "serial/read_serial_data.h"
#include "serial/serial_utils.h"
#include "serial/write_serial_data.h"

/* ============================================================================
 * Constants - Buffer sizes and addresses
 * ============================================================================ */

/* fuji_workspace = $1000 */
#define FUJI_WORKSPACE       0x1000

/* Buffer addresses */
#define FUJI_TX_BUFFER       ((uint8_t*)(FUJI_WORKSPACE + 0x02A0))
#define FUJI_RX_BUFFER       ((uint8_t*)(FUJI_WORKSPACE + 0x0300))
#define FUJI_SLIP_BUFFER     FUJI_RX_BUFFER   /* Reuse RX for SLIP encoding */

/* Buffer sizes - constants */
#define FUJI_TX_BUFFER_SIZE  96
#define FUJI_RX_BUFFER_SIZE  512

/* SLIP protocol */
#define SLIP_END             0xC0
#define SLIP_ESCAPE          0xDB
#define SLIP_ESC_END         0xDC
#define SLIP_ESC_ESC         0xDD

/* FujiBus protocol */
#define FUJIBUS_HEADER_SIZE  6

/* ============================================================================
 * ZeroPage variables - stored in workspace
 * These are used for communication with ASM serial functions
 * ============================================================================ */

/* aws_tmp[4-5] - used by read_serial_data for bytes read count */
#define SERIAL_BYTES_READ    (ZP.aws_tmp[4])

/* ============================================================================
 * SLIP Encoding - minimal version
 * Uses constant buffer size, encodes in-place to SLIP buffer
 * ============================================================================ */

/**
 * SLIP encode to SLIP buffer
 * Input: source pointer, source length
 * Output: encoded length in A
 * Uses: X, Y, temp in zeropage
 */
uint16_t fujibus_slip_encode(uint8_t* src, uint16_t len) {
    uint16_t src_idx;
    uint16_t dst_idx;
    uint8_t b;
    
    dst_idx = 0;
    
    /* Start with END marker */
    FUJI_SLIP_BUFFER[dst_idx++] = SLIP_END;
    
    /* Encode each byte */
    for (src_idx = 0; src_idx < len; src_idx++) {
        b = src[src_idx];
        
        if (b == SLIP_END) {
            FUJI_SLIP_BUFFER[dst_idx++] = SLIP_ESCAPE;
            FUJI_SLIP_BUFFER[dst_idx++] = SLIP_ESC_END;
        } else if (b == SLIP_ESCAPE) {
            FUJI_SLIP_BUFFER[dst_idx++] = SLIP_ESCAPE;
            FUJI_SLIP_BUFFER[dst_idx++] = SLIP_ESC_ESC;
        } else {
            FUJI_SLIP_BUFFER[dst_idx++] = b;
        }
    }
    
    /* End with END marker */
    FUJI_SLIP_BUFFER[dst_idx++] = SLIP_END;
    
    return dst_idx;
}

/* ============================================================================
 * SLIP Decoding - minimal version
 * Decodes from SLIP buffer to RX buffer
 * ============================================================================ */

/**
 * SLIP decode from SLIP buffer
 * Input: encoded length
 * Output: decoded length in A, 0 on error
 * Uses: X, Y
 */
uint16_t fujibus_slip_decode(uint16_t enc_len) {
    uint16_t enc_idx;
    uint16_t dec_idx;
    uint8_t b;
    
    /* Check for valid frame */
    if (enc_len < 2 || FUJI_SLIP_BUFFER[0] != SLIP_END || FUJI_SLIP_BUFFER[enc_len-1] != SLIP_END) {
        return 0;
    }
    
    /* Skip leading END */
    enc_idx = 1;
    dec_idx = 0;
    
    /* Decode until trailing END */
    while (enc_idx < enc_len - 1) {
        b = FUJI_SLIP_BUFFER[enc_idx++];
        
        if (b == SLIP_ESCAPE) {
            /* Handle escape */
            if (enc_idx >= enc_len - 1) {
                break;
            }
            
            b = FUJI_SLIP_BUFFER[enc_idx++];
            
            if (b == SLIP_ESC_END) {
                b = SLIP_END;
            } else if (b == SLIP_ESC_ESC) {
                b = SLIP_ESCAPE;
            }
        } else if (b == SLIP_END) {
            break;
        }
        
        FUJI_RX_BUFFER[dec_idx++] = b;
    }
    
    return dec_idx;
}

/* ============================================================================
 * Packet Building
 * ============================================================================ */

/**
 * Build FujiBus packet in TX buffer
 * Input: device, command, payload pointer, payload length
 * Output: total packet length
 */
uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint16_t paylen) {
    uint16_t total_len;
    uint16_t i;
    uint8_t chk;
    
    /* Total length = header(6) + payload */
    total_len = FUJIBUS_HEADER_SIZE + paylen;
    
    /* Build header */
    FUJI_TX_BUFFER[0] = device;
    FUJI_TX_BUFFER[1] = command;
    FUJI_TX_BUFFER[2] = total_len & 0xFF;          /* Length low */
    FUJI_TX_BUFFER[3] = (total_len >> 8) & 0xFF;
    FUJI_TX_BUFFER[4] = 0;                  /* Checksum placeholder */
    FUJI_TX_BUFFER[5] = 0;                  /* Descriptor */
    
    /* Copy payload */
    for (i = 0; i < paylen; i++) {
        FUJI_TX_BUFFER[FUJIBUS_HEADER_SIZE + i] = payload[i];
    }
    
    /* Calculate checksum (with placeholder = 0) */
    chk = calc_checksum(FUJI_TX_BUFFER, total_len);
    FUJI_TX_BUFFER[4] = chk;
    
    return total_len;
}

/* ============================================================================
 * Send Packet
 * ============================================================================ */

/**
 * Send FujiBus packet
 * Input: device, command, payload pointer, payload length
 * Uses: serial I/O via zeropage
 */
void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen) {
    uint8_t pkt_len;
    uint8_t slip_len;
    
    /* Build packet */
    pkt_len = fujibus_build_packet(device, command, payload, paylen);
    
    /* SLIP encode */
    slip_len = fujibus_slip_encode(FUJI_TX_BUFFER, pkt_len);
    
    setup_serial_19200();

    /* Send via serial - setup zeropage params */
    ZP.aws_tmp[0] = (uint8_t)((uint16_t)FUJI_SLIP_BUFFER & 0xFF);
    ZP.aws_tmp[1] = (uint8_t)(((uint16_t)FUJI_SLIP_BUFFER >> 8) & 0xFF);
    ZP.aws_tmp[2] = slip_len;
    ZP.aws_tmp[3] = 0;
    
    /* Call ASM write_serial_data */
    write_serial_data();
    restore_output_to_screen();
}

/* ============================================================================
 * Receive Packet  
 * ============================================================================ */

/**
 * Receive FujiBus packet into RX buffer
 * Returns: packet length (0 = error)
 */
uint16_t fujibus_receive_packet(void) {
    uint16_t dec_len;
    uint8_t chk_received;
    uint8_t chk_computed;
    uint16_t slip_len = 0;
    
    setup_serial_19200();

    /* Read from serial - setup zeropage params */
    read_serial_data(FUJI_SLIP_BUFFER, 0x00FF, &slip_len);
    restore_output_to_screen();
    
    if (slip_len == 0) {
        return 0;
    }
    
    /* SLIP decode */
    dec_len = fujibus_slip_decode(slip_len);
    
    /* Validate minimum size */
    if (dec_len < FUJIBUS_HEADER_SIZE) {
        return 0;
    }
    
    /* Validate checksum */
    chk_received = FUJI_RX_BUFFER[4];
    FUJI_RX_BUFFER[4] = 0;  /* Clear for calculation */
    chk_computed = calc_checksum(FUJI_RX_BUFFER, dec_len);
    FUJI_RX_BUFFER[4] = chk_received;  /* Restore */
    
    if (chk_received != chk_computed) {
        return 0;
    }
    
    return dec_len;
}

/* ============================================================================
 * Accessor functions for received packet
 * ============================================================================ */

#define fujibus_get_device()     (FUJI_RX_BUFFER[0])
#define fujibus_get_command()    (FUJI_RX_BUFFER[1])
#define fujibus_get_length()     (FUJI_RX_BUFFER[2])
#define fujibus_get_payload()    (&FUJI_RX_BUFFER[FUJIBUS_HEADER_SIZE])

/**
 * Get payload length from received packet
 */
uint8_t fujibus_get_payload_length(void) {
    uint8_t total = fujibus_get_length();
    if (total < FUJIBUS_HEADER_SIZE) {
        return 0;
    }
    return total - FUJIBUS_HEADER_SIZE;
}

