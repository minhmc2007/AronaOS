/*
    Copyright (C) 2025  QUOC TRUNG NGUYEN

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#include "elf/elf.hpp"
#include "paging/paging.hpp"
#include "utils.hpp"
#include <cstddef>
#include <cstdint>

#define kernelAddress 0xffffffff80000000
uint16_t *buffer = (uint16_t *)0xb8000;
int x = 0, y = 0;
uint16_t color = 0x0300;

void putc(char c) {
  if (c == 10) {
    y++;
    x = -1;
  } else {
    buffer[y * 80 + x] = color | c;
  }

  x++;
  if (x >= 80) {
    y++;
    x = 0;
  }

  if (y >= 25) {
    memmove(buffer, buffer + 80, 3840);

    for (int i = 0; i < 80; i++) {
      buffer[24 * 80 + i] = color;
    }

    x = 0;
    y--;
  }
}

void print(const char *s) {
  int i = 0;
  while (s[i] != 0) {
    putc(s[i]);
    i++;
  }
}

void clearScreen() {

  for (int i = 0; i < 80 * 2 * 25; i++) {
    buffer[i] = color;
  }
}

void printUint(uint64_t n) {
  if (n == 0) {
    print("0");
    return;
  }
  char buf[20];
  buf[19] = 0;
  int c = 18;
  while (n != 0) {
    buf[c] = n % 10 + 48;
    c--;

    n /= 10;
  }
  print(&buf[c + 1]);
}

char hexTranslationTab[16] = {'0', '1', '2', '3', '4', '5', '6', '7',
                              '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
void printHex(uint64_t n) {
  print("0x");
  if (n == 0) {
    print("0");
    return;
  }
  char buf[20];
  buf[19] = 0;
  int c = 18;
  while (n != 0) {
    buf[c] = hexTranslationTab[n % 16];
    c--;

    n /= 16;
  }
  print(&buf[c + 1]);
}

void *scanTable(const char *magic) {
  char *buffer = (char *)0x7e00;
  for (int i = 0; i < 512 * 10; i++) {
    if (buffer[i] == magic[0]) { // start check
      int j = 0;
      for (j = j; magic[j] != 0; j++)
        if (magic[j] != buffer[i + j])
          break;

      if (magic[j] == 0)
        return (&buffer[i] + j);
    }
  }

  return 0;
}

bool checkELFMagic(void *address) {
  char *b = (char *)address;

  if (b[0] != 0x7F) {
    return false;
  }

  return memcmp(b + 1, "ELF", 3) == 0;
}

void hlt() {
  asm("hlt");
  for (;;) {
  }
}

typedef struct {
  uint32_t bootstrapSize;
  uint32_t kernelSize;
} BSFS;

extern "C" void callKmain(uint64_t);

extern "C" {
__attribute__((section(".text.entry"))) void bmain() {
  mapPage();
  clearScreen();
  print("parse Kernel ELF...\n");

  BSFS *b = (BSFS *)scanTable("BSFS");

  if (b == 0) {
    print("MAYBE IM NOT BE LOADED BY ARONA BOOTLOADER\n");
    hlt();
  }

  uint32_t kernelELFSize = b->kernelSize;

  print("Kernel elf size = ");
  printUint(kernelELFSize);
  print("\n");

  if (!checkELFMagic((void *)kernelAddress)) {
    print("kernel isn't a ELF");
    hlt();
  }

  ELFHeader *h = (ELFHeader *)kernelAddress;
  ELFHeader kernelELFHeader = *h;

  if (h->bit != 2) {
    print("Only support 64 bit amd64 elf!\n");
    hlt();
  }

  // copy program header to 0x700000
  ProgramHeader *ph =
      (ProgramHeader *)(kernelAddress + h->programHeaderTableOffset);
  memcpy((void *)0x700000, ph,
         sizeof(ProgramHeader) * kernelELFHeader.numberOfProgramHeaderTables);

  ProgramHeader *kernelProgramHeader = (ProgramHeader *)0x700000;

  for (int i = 0; i < kernelELFHeader.numberOfProgramHeaderTables; i++) {
    if (kernelProgramHeader->type == PT_LOAD) {
      uint64_t *dest = (uint64_t *)(kernelProgramHeader->virtualAddress),
               *src = (uint64_t *)(kernelAddress + kernelProgramHeader->offset);
      for (uint64_t i = 0; i < kernelProgramHeader->fileSize / 8 + 1; i++) {
        dest[i] = src[i];
      }

      // fill bss with zero
      char *bssSection = (char *)(kernelProgramHeader->virtualAddress +
                                  kernelProgramHeader->fileSize);

      for (uint32_t i = 0;
           i < (kernelProgramHeader->memSize - kernelProgramHeader->fileSize);
           i++) {
        bssSection[i] = 0;
      }
    }

    kernelProgramHeader += 1;
  }

  callKmain(kernelELFHeader.EntryOffset);

  // hlt();
}
}
