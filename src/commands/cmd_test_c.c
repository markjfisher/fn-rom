/**
 * Test C code for FujiBus
 * Tests fujibus_slip_encode, fujibus_slip_decode, and fujibus_build_packet
 */

#include <stdint.h>
#include "zp_overlay.h"
#include "fujibus_c.h"

#include "cmd_test_c.h"

/**
 * Test fujibus_build_packet, fujibus_slip_encode, and fujibus_slip_decode
 */
void cmd_test_c(void) {
    uint8_t payload[8];
    uint8_t test_data[20];
    uint8_t enc_len;
    uint8_t dec_len;
    uint8_t pkt_len;
    uint8_t match;
    uint8_t chk;
    
    /* ======================================== */
    /* Test 1: fujibus_build_packet */
    /* ======================================== */
    
    /* Create test payload */
    payload[0] = 0x12;
    payload[1] = 0x34;
    payload[2] = 0x56;
    payload[3] = 0x78;
    
    /* Build packet: device=0xF0, command=0x01, 4 byte payload */
    pkt_len = fujibus_build_packet(0xF0, 0x01, payload, 4);
    
    /* Verify packet: header(6) + payload(4) = 10 bytes */
    match = 1;
    if (pkt_len != 10) {
        match = 0;
    }
    
    /* Check header */
    if (match) {
        if (FUJI_TX_BUFFER[0] != 0xF0) match = 0;  /* device */
        if (FUJI_TX_BUFFER[1] != 0x01) match = 0;  /* command */
        if (FUJI_TX_BUFFER[2] != 10) match = 0;    /* length low */
        if (FUJI_TX_BUFFER[3] != 0x00) match = 0;  /* length high */
        if (FUJI_TX_BUFFER[5] != 0x00) match = 0;  /* descriptor */
    }
    
    /* Check payload */
    if (match) {
        if (FUJI_TX_BUFFER[6] != 0x12) match = 0;
        if (FUJI_TX_BUFFER[7] != 0x34) match = 0;
        if (FUJI_TX_BUFFER[8] != 0x56) match = 0;
        if (FUJI_TX_BUFFER[9] != 0x78) match = 0;
    }
    
    /* Check checksum is non-zero */
    chk = FUJI_TX_BUFFER[4];
    if (chk == 0) match = 0;
    
    if (match == 0) {
        v1 = 1;  /* build failed */
        v2 = pkt_len;
        return;
    }
    
    /* ======================================== */
    /* Test 2: fujibus_slip_encode */
    /* ======================================== */
    
    /* Create test data with bytes needing escaping */
    test_data[0] = 0x00;
    test_data[1] = 0x01;
    test_data[2] = SLIP_END;       /* 0xC0 - needs escape */
    test_data[3] = SLIP_ESCAPE;    /* 0xDB - needs escape */
    test_data[4] = 0x42;
    test_data[5] = SLIP_END;       /* Another END */
    test_data[6] = SLIP_ESCAPE;    /* Another ESCAPE */
    test_data[7] = 0x99;
    test_data[8] = 0x00;
    
    /* Encode */
    enc_len = fujibus_slip_encode(test_data, 9);
    
    /* Verify encoded output: C0 00 01 DB DC DB DD 42 DB DC DB DD 99 00 C0 */
    /* That's 15 bytes total */
    match = 1;
    if (enc_len != 15) {
        match = 0;
    }
    if (match) {
        if (FUJI_SLIP_BUFFER[0] != 0xC0) match = 0;  /* END */
        if (FUJI_SLIP_BUFFER[1] != 0x00) match = 0;
        if (FUJI_SLIP_BUFFER[2] != 0x01) match = 0;
        if (FUJI_SLIP_BUFFER[3] != SLIP_ESCAPE) match = 0;
        if (FUJI_SLIP_BUFFER[4] != SLIP_ESC_END) match = 0;   /* -> C0 */
        if (FUJI_SLIP_BUFFER[5] != SLIP_ESCAPE) match = 0;
        if (FUJI_SLIP_BUFFER[6] != SLIP_ESC_ESC) match = 0;    /* -> DB */
        if (FUJI_SLIP_BUFFER[7] != 0x42) match = 0;
        if (FUJI_SLIP_BUFFER[8] != SLIP_ESCAPE) match = 0;
        if (FUJI_SLIP_BUFFER[9] != SLIP_ESC_END) match = 0;   /* -> C0 */
        if (FUJI_SLIP_BUFFER[10] != SLIP_ESCAPE) match = 0;
        if (FUJI_SLIP_BUFFER[11] != SLIP_ESC_ESC) match = 0;  /* -> DB */
        if (FUJI_SLIP_BUFFER[12] != 0x99) match = 0;
        if (FUJI_SLIP_BUFFER[13] != 0x00) match = 0;
        if (FUJI_SLIP_BUFFER[14] != 0xC0) match = 0;  /* END */
    }
    
    if (match == 0) {
        v1 = 2;  /* encode failed */
        v2 = enc_len;
        return;
    }
    
    /* ======================================== */
    /* Test 3: fujibus_slip_decode */
    /* ======================================== */
    
    /* Setup known encoded data in SLIP buffer */
    FUJI_SLIP_BUFFER[0] = SLIP_END;
    FUJI_SLIP_BUFFER[1] = 0x00;
    FUJI_SLIP_BUFFER[2] = 0x01;
    FUJI_SLIP_BUFFER[3] = SLIP_ESCAPE;
    FUJI_SLIP_BUFFER[4] = SLIP_ESC_END;    /* -> 0xC0 */
    FUJI_SLIP_BUFFER[5] = SLIP_ESCAPE;
    FUJI_SLIP_BUFFER[6] = SLIP_ESC_ESC;    /* -> 0xDB */
    FUJI_SLIP_BUFFER[7] = 0x42;
    FUJI_SLIP_BUFFER[8] = SLIP_END;        /* trailing END */
    
    /* Decode */
    dec_len = fujibus_slip_decode(9);
    
    /* Check decoded length should be 5: 0x00, 0x01, 0xC0, 0xDB, 0x42 */
    match = 1;
    if (dec_len != 5) {
        match = 0;
    }
    
    /* Check decoded bytes */
    if (match) {
        if (FUJI_RX_BUFFER[0] != 0x00) match = 0;
        if (FUJI_RX_BUFFER[1] != 0x01) match = 0;
        if (FUJI_RX_BUFFER[2] != SLIP_END) match = 0;  /* 0xC0 */
        if (FUJI_RX_BUFFER[3] != SLIP_ESCAPE) match = 0; /* 0xDB */
        if (FUJI_RX_BUFFER[4] != 0x42) match = 0;
    }
    
    /* All tests passed */
    v1 = match;  /* 0 = failed, 1 = passed */
    v2 = dec_len;
}
