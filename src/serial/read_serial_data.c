#include <stdint.h>
#include "zp_overlay.h"

// Assembly helper functions

extern uint8_t __fastcall__ check_rs423_buffer(void);
extern uint8_t __fastcall__ read_rs423_char(void);

// read_serial_data - Read multiple bytes from RS423 buffer

// this is set to 0 for success, -1 for error in _read_rs423_char
#define got_char    (ZP.cws_tmp[0])

#define SLIP_END          0xC0
#define WAIT_FIRST_MAX    ((uint16_t) 50000)
#define WAIT_NEXT_MAX     ((uint16_t) 2000)

uint8_t read_serial_data(uint8_t *dst, uint16_t len, uint16_t *count) {
    uint8_t ch_byte;
    uint16_t wait_count;
    uint16_t wait_limit;
    uint16_t i  = 0;

    while (i < len) {
        ch_byte    = 0;
        wait_count = 0;
        wait_limit = (i == 0) ? WAIT_FIRST_MAX : WAIT_NEXT_MAX;

        while (wait_count < wait_limit) {
            if (check_rs423_buffer() != 0) {
                ch_byte = read_rs423_char();
                break;
            }
            ++wait_count;
        }

        if (wait_count >= wait_limit || got_char != 0) {
            break;
        }

        dst[i] = ch_byte;
        ++i;
        ++(*count);

        /* FujiBus packets are SLIP framed. Once we have seen the terminating
         * END byte we already have the full frame, so avoid waiting for an
         * idle timeout after every response.
         */
        if (i > 1 && ch_byte == SLIP_END) {
            break;
        }
    }
    return (*count == len) ? 1 : 0;
}