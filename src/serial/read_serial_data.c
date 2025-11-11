#include <stdint.h>
#include "zp_overlay.h"

// Assembly helper functions

extern uint8_t __fastcall__ check_rs423_buffer(void);
extern uint8_t __fastcall__ read_rs423_char(void);
extern void    __fastcall__ write_byte_to_buffer(void);
extern void    __fastcall__ vblank(uint8_t n);

// read_serial_data - Read multiple bytes from RS423 buffer
// Matches test.c read_serial_data() behavior with tight polling loop
//
// Input (in ZP vars):
//   aws_tmp00_01 = pointer to buffer (16-bit)
//   aws_tmp02_03 = length to read (16-bit)
//
// Output (in ZP vars):
//   aws_tmp04_05 = bytes actually read (16-bit)
//   A = status: 0=error, 1=success

// INPUT PARAMS - MUST BE SET BY CALLER
// #define bytes_ptr   (*(volatile uint16_t*)&ZP.aws_tmp[0])
#define bytes_ptr   (*(volatile uint8_t* *)(void*)&ZP.aws_tmp[0])
#define bytes_len   (*(volatile uint16_t*)&ZP.aws_tmp[2])

// OUTPUT:
#define bytes_read  (*(volatile uint16_t*)&ZP.aws_tmp[4])

// General variables:
#define i_counter   (*(volatile uint16_t*)&ZP.aws_tmp[6])
#define wait_count  (*(volatile uint16_t*)&ZP.aws_tmp[8])
#define ch_byte     (ZP.aws_tmp[10])
// set to 0 for success, -1 for error
#define got_char    (ZP.cws_tmp[0])

// #define calc_addr (*(volatile uint8_t* *)(void*)&ZP.aws_tmp[12])

#define WAIT_MAX  ((uint16_t) 2000)

void write_byte_to_buffer(void) {
    bytes_ptr[i_counter] = ch_byte;
}

// TODO: if this is never used, remove it
void drain_data(void) {
    i_counter = 0;

    while (i_counter < bytes_len) {
        wait_count = 0;
        while (wait_count < 100) {
            if (check_rs423_buffer() != 0) {
                read_rs423_char();
                break;
            }
            vblank(1);
            ++wait_count;
        }
        if (wait_count >= WAIT_MAX) {
            break;
        }
        ++i_counter;
    }
}

uint8_t read_serial_data(void) {
    bytes_read = 0;
    i_counter  = 0;

    while (i_counter < bytes_len) {
        ch_byte    = 0;
        wait_count = 0;

        while (wait_count < WAIT_MAX) {
            if (check_rs423_buffer() != 0) {
                ch_byte = read_rs423_char();
                break;
            }
            // vblank(1);
            ++wait_count;
        }

        if (wait_count >= WAIT_MAX || got_char != 0) {
            ch_byte = 0;
            // pad zeros to the end
            while (i_counter < bytes_len) {
                write_byte_to_buffer();
                ++i_counter;
            }
            break;
        }

        write_byte_to_buffer();
        ++i_counter;
        ++bytes_read;
    }
    // using a ternary means CC65 doesn't pull in booleq and all the 40 or so bytes of makebool.s
    return (bytes_read == bytes_len) ? 1 : 0;
}
