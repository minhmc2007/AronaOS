#ifndef PREKERNEL_DISK
#define PREKERNEL_DISK

#include <stdint.h>

typedef struct {
  uint8_t size;
  uint8_t reserved;
  uint16_t sectors;
  uint32_t offset;
  uint64_t LBA;
} __attribute__((packed)) diskAddressPacket;

typedef struct {
  uint32_t diskLoadData;
  uint8_t bootDrive;
  diskAddressPacket DAP;
  uint32_t outputAddress;
  uint8_t result;
} __attribute__((packed)) DLD;

#endif