/**
 * Test C code for FujiBus SLIP encoding/decoding
 * Tests the fujibus_slip_encode and fujibus_slip_decode functions
 */

#include <stdint.h>
#include "zp_overlay.h"
#include "fujibus_c.h"

#include "cmd_test_c.h"

/* External ASM function for printing */
// extern void print_hex(uint8_t value);
// extern void print_string(uint8_t* str);

/**
 * Test SLIP encode/decode with data that requires escaping
 */
void cmd_test_c(void) {
    /* Test data - includes bytes that need SLIP escaping */
    uint8_t test_data[20];
    uint8_t enc_len;
    uint8_t dec_len;
    uint8_t match;
    
    /* Fill test buffer with values including SLIP special bytes */
    test_data[0] = 0x00;              /* Normal */
    test_data[1] = 0x01;              /* Normal */
    test_data[2] = SLIP_END;          /* 0xC0 - needs escape */
    test_data[3] = SLIP_ESCAPE;       /* 0xDB - needs escape */
    test_data[4] = 0x42;              /* 'B' - normal */
    test_data[5] = SLIP_END;          /* Another END */
    test_data[6] = SLIP_ESCAPE;       /* Another ESCAPE */
    test_data[7] = 0x99;              /* Normal */
    test_data[8] = 0x00;              /* End marker in original */
    
    /* Call SLIP encode - result goes to SLIP buffer */
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
    
    /* If encode fails, don't bother testing decode */
    if (match == 0) {
        v1 = 0;
        v2 = enc_len;
        return;
    }
    
    /* Test decode by manually setting up SLIP buffer with known encoded data */
    /* Create encoded data manually in SLIP buffer */
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
    
    /* Check decoded length should be 5 */
    /* Should have: 0x00, 0x01, 0xC0, 0xDB, 0x42 */
    
    /* Compare with expected */
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
    
    /* Store result - using ZP overlay to write to known location */
    v1 = match;
    v2 = dec_len;
}
