// zp_overlay.h
#include <stdint.h>

typedef struct {
    uint8_t  cws_tmp[8];     // 0xA8..0xAF
    uint8_t  aws_tmp[16];    // 0xB0..0xBF
    uint8_t  pws_tmp[16];    // 0xC0..0xCF
} ZPLayout;

#define ZP   (*(volatile ZPLayout*)0x00A8)

/*

Allows us to write variables in C like:

// 8 bit value
#define ch_byte     (ZP.aws_tmp[10])

// pointer to byte
#define bytes_ptr   (*(volatile uint8_t* *)(void*)&ZP.aws_tmp[0])

// 16 bit value
#define bytes_len   (*(volatile uint16_t*)&ZP.aws_tmp[2])

# Limitations of C

Do not use compound calculations, but split them into individual steps
this avoids stack for temporary assignment, e.g.:

    foo[x] = bar[y] - baz[z];

instead use partial results which all store in ZP values:

    t_1 = bar[y];
    t_2 = baz[z];
    foo[x] = t_1 - t_2;

 */
