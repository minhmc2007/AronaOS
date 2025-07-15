#include "slabAllocator.h"
#include <stdint.h>

const uint32_t NUMBER_OF_SLAB_INFO = ALLOCATOR_POOL_SIZE / 4 / 32;
const uint32_t NUMBER_OF_SLAB =
    (ALLOCATOR_POOL_SIZE - SMALLEST_SLAB * NUMBER_OF_SLAB_INFO * 4) /
    SMALLEST_SLAB;
// because we in 32 bit protected mode, use 32 bit data type will be better
uint32_t *slabTable;
uint32_t *slabs;

int getSlabInfo(uint32_t index) {
  uint32_t offset = index / 32;
  index = index % 32;

  return ((slabTable[offset] >> index) & 0x1);
}

void setSlabInfo(uint32_t index, int val) {
  uint32_t offset = index / 32;
  index = index % 32;

  if (val == 1) {
    slabTable[offset] = (uint32_t)slabTable[offset] |
                        (uint32_t)((uint32_t)1 << (uint32_t)index);
  } else if (val == 0) {
    slabTable[offset] = (uint32_t)slabTable[offset] &
                        (uint32_t)~((uint32_t)1 << (uint32_t)index);
  }
}

extern void printUint(uint32_t v);
extern void print_str(const char *);

void initAllocator(void *offset) {
  slabTable = offset;

  for (int i = 0; i < NUMBER_OF_SLAB_INFO; i++) {
    slabTable[i] = 0;
  }

  slabs = &slabTable[NUMBER_OF_SLAB_INFO];
}

void *smalloc(uint32_t size) {
  if (size == 0) {
    return 0;
  }

  while ((size % SMALLEST_SLAB) != 0) // inc til get a suitable size
    size++;

  uint32_t blockNeed = size / SMALLEST_SLAB;
  for (uint32_t i = 0; i < NUMBER_OF_SLAB; i++) {
    if (!getSlabInfo(i)) { // find a free block
      uint32_t c = 1;
      while (c != blockNeed && (i + c) < NUMBER_OF_SLAB) // find more block
        if (!getSlabInfo(c + i))
          c++;

      if (c == blockNeed) {

        for (uint32_t j = i; j < (c + i); j++) {
          setSlabInfo(j, 1);
          print_str("alloc slab ");
          printUint(j);
          print_str("\n");
        }

        return &slabs[i];
      }

      // if not then increase i by c
      i += c;
    }
  }

  return 0;
}

void sfree(void *address, uint32_t size) {
  while ((size % SMALLEST_SLAB) != 0) // inc til get a suitable size
    size++;

  size /= 4;
  uint32_t slabT = ((uint32_t)address - (uint32_t)slabs) / 4;

  for (uint32_t i = 0; i < size; i++) {
    setSlabInfo(i + slabT, 0);

    print_str("free slab ");
    printUint(i + slabT);
    print_str("\n");
  }
}