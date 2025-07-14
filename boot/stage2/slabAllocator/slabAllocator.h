#include <stdint.h>
#ifndef PREKERNEL_SLAB_ALLOCATOR
#define PREKERNEL_SLAB_ALLOCATOR

#define SMALLEST_SLAB 4 // smallest slab is 4 bytes

// per allocator hold 1 MB
#define ALLOCATOR_POOL_SIZE 0x100000

void initAllocator(void *offset);
void sfree(void *address, uint32_t size);
void *smalloc(uint32_t size);

#endif