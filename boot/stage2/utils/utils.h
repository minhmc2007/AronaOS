#ifndef PRE_KERNEL_UTILS
#define PRE_KERNEL_UTILS
#include <stddef.h>
extern int getStringLength(const char *s);
void *memcpy(void *, const void *, size_t);
#endif