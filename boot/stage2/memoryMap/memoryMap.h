#ifndef PRE_KERNEL_MEMORY_MAP
#define PRE_KERNEL_MEMORY_MAP
#include <stdint.h>
extern void *scanBootTable(const char *magic);

typedef struct {
  uint64_t baseAddr;
  uint64_t length;
  uint32_t type;
} __attribute__((packed)) UpperMemoryMap;

typedef struct {
  uint32_t memoryMapLength;
  uint64_t memoryMapPointer;
} __attribute__((packed)) TUMPPointer;
#endif