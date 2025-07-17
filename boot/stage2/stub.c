#include <stddef.h>
#include <stdint.h>

void *memcpy(void *str1, const void *str2, size_t n) {
  char *s1 = str1;
  char *s2 = (char *)str2;
  for (uint32_t i = 0; i < n; i++) {
    s1[i] = s2[i];
  }

  return s1;
}