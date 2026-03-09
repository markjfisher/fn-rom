#ifndef READ_SERIAL_DATA_H
#define READ_SERIAL_DATA_H

#include <stdint.h>

// uint8_t read_serial_data(void);
uint8_t read_serial_data(uint8_t *dst, uint16_t len, uint16_t *count);

#endif // READ_SERIAL_DATA_H