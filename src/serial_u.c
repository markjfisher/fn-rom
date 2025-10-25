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
void read_serial_data(void) {
    uint8_t *buffer = (uint8_t*)pws_tmp00_01;
    
    // Initialize bytes_received = 0
    pws_tmp04_05 = 0;
    
    // Loop for each byte (i = 0; i < length; i++)
    for (aws_tmp06_07 = 0; aws_tmp06_07 < pws_tmp02_03; aws_tmp06_07++) {
        aws_tmp10 = 0;      // ch = 0
        aws_tmp11 = 0;      // got_char = 0
        aws_tmp08_09 = 0;   // wait_count = 0
        
        // Wait for data to be available (while wait_count < 10000)
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
            while (aws_tmp06_07 < pws_tmp02_03) {
                buffer[aws_tmp06_07] = 0;
                aws_tmp06_07++;
            }
            break;
        }
        
        // Store the character
        buffer[aws_tmp06_07] = aws_tmp10;
        pws_tmp04_05++;  // bytes_received++
    }
    
    // Set status: 1 if all bytes read, 0 if timeout
    aws_tmp00 = (pws_tmp04_05 == pws_tmp02_03) ? 1 : 0;
}
