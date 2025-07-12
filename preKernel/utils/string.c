#include "utils.h"

int getStringLength(const char *s) {
  int c = 0;
  for (int i = 0; s[i] != 0; i++) {
    c++;
  }

  return c;
}