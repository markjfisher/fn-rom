#include <stdint.h>
#include "zp_overlay.h"

#include "cmd_test_c.h"

extern void remember_axy();

uint16_t inc_num(uint16_t n) {
    return n + 1;
}

void cmd_test_c() {
    uint8_t a, b, c;
    uint8_t buf[20];

    remember_axy();
    v1 = 0x69;

    for (a = 0; a < 5; a++) {
        b = a * 2;
        c = b + 5;
        buf[a] = buf[b] + buf[c] + (inc_num(a) % 256);
    }

    v2 = 0x96;
}