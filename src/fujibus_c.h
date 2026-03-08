/**
 * FujiBus Protocol C Interface - Header File
 * 
 * Functions for SLIP encoding/decoding and FujiBus packet handling
 * for BBC Micro communication with FujiNet devices.
 */

#ifndef FUJIBUS_C_H
#define FUJIBUS_C_H

#include <stdint.h>
#include <stdbool.h>

/* ============================================================================
 * Constants
 * ============================================================================ */

#define FUJIBUS_SLIP_END       0xC0
#define FUJIBUS_SLIP_ESCAPE    0xDB
#define FUJIBUS_SLIP_ESC_END   0xDC
#define FUJIBUS_SLIP_ESC_ESC   0xDD

#define FUJIBUS_HEADER_SIZE    6
#define FUJIBUS_MAX_SLIP_SIZE  640
#define FUJIBUS_MAX_PACKET     320

/* Buffer addresses */
#define FUJI_TX_BUFFER     ((uint8_t*)0x12A0)
#define FUJI_RX_BUFFER     ((uint8_t*)0x1300)
#define FUJI_SLIP_BUFFER   FUJI_RX_BUFFER

/* ============================================================================
 * Buffer Length Variables (in zeropage workspace)
 * ============================================================================ */

/* These are declared in the C code and map to zeropage */
extern uint8_t fujibus_tx_len;
extern uint8_t fujibus_tx_len_hi;
extern uint8_t fujibus_rx_len;
extern uint8_t fujibus_rx_len_hi;

/* ============================================================================
 * SLIP Encoding Functions
 * ============================================================================ */

/**
 * Encode data with SLIP framing
 * @param input Pointer to data to encode
 * @param len Length of input data
 * @return Length of encoded data
 */
uint16_t fujibus_slip_encode(uint8_t* input, uint16_t len);

/* ============================================================================
 * SLIP Decoding Functions
 * ============================================================================ */

/**
 * Decode SLIP-framed data
 * @param input Pointer to SLIP-encoded data
 * @param len Length of encoded data
 * @return Length of decoded data, 0 on error
 */
uint16_t fujibus_slip_decode(uint8_t* input, uint16_t len);

/* ============================================================================
 * Packet Building Functions
 * ============================================================================ */

/**
 * Build a FujiBus packet
 * @param device Device ID
 * @param command Command byte
 * @param payload Pointer to payload data
 * @param paylen Payload length
 * @return Total packet length
 */
uint16_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen);

/* ============================================================================
 * Packet Transmission Functions
 * ============================================================================ */

/**
 * Send a FujiBus packet via serial
 * @param device Device ID
 * @param command Command byte
 * @param payload Pointer to payload data
 * @param paylen Payload length
 * @return true on success, false on error
 */
bool fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen);

/* ============================================================================
 * Packet Reception Functions
 * ============================================================================ */

/**
 * Receive a FujiBus packet via serial
 * @param max_len Maximum length to read
 * @return Length of received packet, 0 on error
 */
uint16_t fujibus_receive_packet(uint16_t max_len);

/**
 * Get received packet device ID
 * @return Device ID from last received packet
 */
uint8_t fujibus_get_device(void);

/**
 * Get received packet command
 * @return Command byte from last received packet
 */
uint8_t fujibus_get_command(void);

/**
 * Get received packet total length
 * @return Total packet length from header
 */
uint16_t fujibus_get_length(void);

/**
 * Get pointer to received packet payload
 * @return Pointer to payload data in RX buffer
 */
uint8_t* fujibus_get_payload(void);

/**
 * Get received packet payload length
 * @return Payload length
 */
uint8_t fujibus_get_payload_length(void);

#endif /* FUJIBUS_C_H */
