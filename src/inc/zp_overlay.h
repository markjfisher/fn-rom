// zp_overlay.h
#include <stdint.h>

#pragma pack(push, 1)
typedef struct {
    uint8_t  cws_tmp[8];     // 0xA8..0xAF
    uint8_t  aws_tmp[16];    // 0xB0..0xBF
    uint8_t  pws_tmp[16];    // 0xC0..0xCF
} ZPLayout;
#pragma pack(pop)

#define ZP   (*(volatile ZPLayout*)0x00A8)
