#include <cstddef>
#include <cstdint>
// sometimes c++ compiler will generate some calls to these functions
extern "C" {

void *memcpy(void *dest, const void *src, size_t l) {
  char *ddest = (char *)dest, *ssrc = (char *)src;

  if (src > dest)
    for (uint32_t i = 0; i < l; i++)
      ddest[i] = ssrc[i];
  else if (dest > src)
    for (uint32_t i = l; i > 0; i--)
      ddest[i - 1] = ssrc[i - 1];

  return dest;
}

void *memmove(void *dest, const void *src, size_t l) {
  char *ddest = (char *)dest, *ssrc = (char *)src;

  for (uint32_t i = 0; i < l; i++) {
    ddest[i] = ssrc[i];
    ssrc[i] = 0;
  }

  return dest;
}

void *memset(void *ptr, int value, size_t num) {
  char *pptr = (char *)ptr;
  unsigned char v = value;

  for (uint32_t i = 0; i < num; i++)
    pptr[i] = v;

  return ptr;
}

int memcmp(const void *ptr1, const void *ptr2, size_t num) {
  char *p1 = (char *)ptr1, *p2 = (char *)ptr2;

  for (uint32_t i = 0; i < num; i++) {
    if (p1[i] != p2[i]) {
      if (p1[i] > p2[i])
        return 1;
      else
        return -1;
    }
  }

  return 0;
}
}