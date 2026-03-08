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

#define FUJI_WORKSPACE           0x1000
#define FUJI_TX_BUFFER           ((uint8_t*)(FUJI_WORKSPACE + 0x02A0))
#define FUJI_RX_BUFFER           ((uint8_t*)(FUJI_WORKSPACE + 0x0300))
#define FUJI_SLIP_BUFFER         FUJI_RX_BUFFER

#define FUJI_TX_BUFFER_SIZE      96
#define FUJI_RX_BUFFER_SIZE      512

#define SLIP_END                 0xC0
#define SLIP_ESCAPE              0xDB
#define SLIP_ESC_END             0xDC
#define SLIP_ESC_ESC             0xDD

#define FUJIBUS_HEADER_SIZE      6

/* ============================================================================
 * Functions
 * ============================================================================ */

/**
 * SLIP encode to SLIP buffer
 * @param src Source data pointer
 * @param len Source data length
 * @return Encoded length
 */
uint8_t fujibus_slip_encode(uint8_t* src, uint8_t len);

/**
 * SLIP decode from SLIP buffer
 * @param enc_len Encoded data length
 * @return Decoded length, 0 on error
 */
uint8_t fujibus_slip_decode(uint8_t enc_len);

/**
 * Build FujiBus packet in TX buffer
 * @param device Device ID
 * @param command Command byte
 * @param payload Payload pointer
 * @param paylen Payload length
 * @return Total packet length
 */
uint8_t fujibus_build_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen);

/**
 * Send FujiBus packet via serial
 * @param device Device ID
 * @param command Command byte
 * @param payload Payload pointer
 * @param paylen Payload length
 */
void fujibus_send_packet(uint8_t device, uint8_t command, uint8_t* payload, uint8_t paylen);

/**
 * Receive FujiBus packet into RX buffer
 * @return Packet length (0 = error)
 */
uint8_t fujibus_receive_packet(void);

/* Accessor macros - inline for zero overhead */
#define fujibus_get_device()        (FUJI_RX_BUFFER[0])
#define fujibus_get_command()        (FUJI_RX_BUFFER[1])
#define fujibus_get_length()         (FUJI_RX_BUFFER[2])
#define fujibus_get_payload()        (&FUJI_RX_BUFFER[FUJIBUS_HEADER_SIZE])

/**
 * Get payload length from received packet
 */
uint8_t fujibus_get_payload_length(void);

#endif /* FUJIBUS_C_H */
