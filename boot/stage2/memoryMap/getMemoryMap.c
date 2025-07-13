
#include "../utils/utils.h"
extern void print_str(const char *, ...);
// brute force search table with magic
void *scanBootTable(const char *magic) {
  if (getStringLength(magic) < 1) {
    return 0;
  }

  char *offset = (char *)0x7c00; // we load the bootloader into 0x7c00, some
                                 // tables could be here

  for (int i = 0; i < 2048; i++) { // search through 1024 bytes
    if (offset[i] == magic[0]) {
      int notFound = 0;
      for (int j = 1; j < getStringLength(magic); j++) {
        if (offset[i + j] != magic[j]) {
          notFound = 1;
          break;
        }
      }

      if (!notFound) // if we found
        return (char *)&offset[i] + (getStringLength(magic));
    }
  }

  return 0;
}