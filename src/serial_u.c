#include <stdint.h>
#include "vars.h"

// Assembly helper functions (defined in serial_u_asm.s)
// These will be called with C name, but implemented as _funcname in asm
uint8_t check_rs423_buffer(void);  // Returns number of chars in buffer
uint8_t read_rs423_char(void);     // Returns character, or 0xFF if none

// read_serial_data - Read multiple bytes from RS423 buffer
// Matches test.c read_serial_data() behavior with tight polling loop
//
// Input (in ZP vars):
//   pws_tmp00_01 = pointer to buffer (16-bit)
//   pws_tmp02_03 = length to read (16-bit)
//
// Output (in ZP vars):
//   pws_tmp04_05 = bytes actually read (16-bit)
//   aws_tmp00 = status: 0=timeout, 1=success
//
// Working vars used (will alias these in vars.h for clarity):
//   aws_tmp06_07 = i (loop counter, 16-bit)
//   aws_tmp08_09 = wait_count (16-bit)
//   aws_tmp10 = ch (character read)
//   aws_tmp11 = got_char flag
//
// Helper to write byte to buffer using pointer arithmetic
// We CANNOT use local variables or array notation - must use only ZP vars
// Implemented in serial_u_asm.s
//
// Uses pws_tmp06/07 as temporary storage for calculated address
// (pws_tmp06/07 is safe to use as it's only used by other commands like
//  cmd_copy.s and cmd_free_map.s, which won't be executing at the same time)
void write_byte_to_buffer(void);  // In assembly

void read_serial_data(void) {
    // Initialize bytes_received = 0
    pws_tmp04_05 = 0;
    
    // Initialize loop counter aws_tmp06_07 = 0
    aws_tmp06_07 = 0;
    
    // Main loop: while (aws_tmp06_07 < pws_tmp02_03)
    while (aws_tmp06_07 < pws_tmp02_03) {
        aws_tmp10 = 0;      // ch = 0
        aws_tmp11 = 0;      // got_char = 0
        aws_tmp08_09 = 0;   // wait_count = 0
        
        // Inner wait loop: while (wait_count < 10000)
        while (aws_tmp08_09 < 10000) {
            // Check if RS423 buffer has data
            if (check_rs423_buffer() != 0) {
                // Data available - read it
                aws_tmp10 = read_rs423_char();
                if (aws_tmp10 != 0xFF) {  // 0xFF = error
                    aws_tmp11 = 1;  // got_char = 1
                }
                break;
            }
            aws_tmp08_09++;  // wait_count++
        }
        
        // Check timeout or no char
        if (aws_tmp08_09 >= 10000 || aws_tmp11 == 0) {
            // Timeout - fill remaining with zeros
            aws_tmp10 = 0;  // Store zero
            while (aws_tmp06_07 < pws_tmp02_03) {
                write_byte_to_buffer();  // Writes aws_tmp10 to (pws_tmp00_01)[aws_tmp06_07]
                aws_tmp06_07++;
            }
            break;
        }
        
        // Store the character (aws_tmp10 already contains it)
        write_byte_to_buffer();  // Writes aws_tmp10 to (pws_tmp00_01)[aws_tmp06_07]
        aws_tmp06_07++;
        pws_tmp04_05++;  // bytes_received++
    }
    
    // Set status: 1 if all bytes read, 0 if timeout
    aws_tmp00 = (pws_tmp04_05 == pws_tmp02_03) ? 1 : 0;
}
