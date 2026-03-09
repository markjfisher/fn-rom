#include <stdint.h>
#include "zp_overlay.h"

// Assembly helper functions

extern uint8_t __fastcall__ check_rs423_buffer(void);
extern uint8_t __fastcall__ read_rs423_char(void);

// read_serial_data - Read multiple bytes from RS423 buffer

// this is set to 0 for success, -1 for error in _read_rs423_char
#define got_char    (ZP.cws_tmp[0])

#define WAIT_MAX  ((uint16_t) 2000)

uint8_t read_serial_data(uint8_t *dst, uint16_t len, uint16_t *count) {
    uint8_t ch_byte;
    uint16_t wait_count;
    uint16_t i  = 0;

    while (i < len) {
        ch_byte    = 0;
        wait_count = 0;

        while (wait_count < WAIT_MAX) {
            if (check_rs423_buffer() != 0) {
                ch_byte = read_rs423_char();
                break;
            }
            ++wait_count;
        }

        if (wait_count >= WAIT_MAX || got_char != 0) {
            // do we want to pad?
            // pad zeros to the end
            // ch_byte = 0;
            // while (i < len) {
            //     dst[i] = ch_byte;
            //     ++i;
            // }
            break;
        }

        dst[i] = ch_byte;
        ++i;
        ++(*count);
    }
    return (*count == len) ? 1 : 0;
}
