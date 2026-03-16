#ifndef CMD_FLIST_C_H
#define CMD_FLIST_C_H

#include <stdint.h>

uint8_t cmd_fs_flist(void);
bool flist_resolve_target(void);
bool flist_list_page(uint16_t start_index, uint8_t* returned_count, bool* more);

#endif /* CMD_FLIST_C_H */
