#include <cstddef>
#pragma once

extern "C" {
void *memcpy(void *dest, const void *src, size_t l);
void *memmove(void *dest, const void *src, size_t l);
void *memset(void *ptr, int value, size_t num);
int memcmp(const void *ptr1, const void *ptr2, size_t num);
}