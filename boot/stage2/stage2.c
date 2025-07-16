#include "disk/disk.h"
#include "fs/fat32/fat.h"
#include "memoryMap/memoryMap.h"
#include "slabAllocator/slabAllocator.h"
#include <stdalign.h>
#include <stdint.h>

#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define CMD_BUFFER_SIZE 256

static uint16_t *const VGA_BUFFER = (uint16_t *)0xB8000;
static int cursor_row = 1;
static int cursor_col = 0;
static uint8_t color = 0xf5; // purple on white

void checkMemoryMap();

// Custom string functions
int custom_strcmp(const char *a, const char *b) {
  while (*a && *b && *a == *b) {
    a++;
    b++;
  }
  return *a - *b;
}

int custom_strncmp(const char *a, const char *b, int n) {
  for (int i = 0; i < n; i++) {
    if (a[i] != b[i])
      return a[i] - b[i];
    if (a[i] == '\0')
      return 0;
  }
  return 0;
}

// VGA functions
void clear_screen() {
  for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
    VGA_BUFFER[i] = (uint16_t)color << 8 | ' ';
  }
  cursor_row = 0;
  cursor_col = 0;
}

void update_cursor() {
  uint16_t pos = cursor_row * VGA_WIDTH + cursor_col;
  // Output low byte
  asm volatile("outb %0, %1" : : "a"((uint8_t)(pos & 0xFF)), "Nd"(0x3D4));
  // Output high byte
  asm volatile("outb %0, %1"
               :
               : "a"((uint8_t)((pos >> 8) & 0xFF)), "Nd"(0x3D4));
}

void newline() {
  cursor_col = 0;
  if (++cursor_row >= VGA_HEIGHT) {
    cursor_row = VGA_HEIGHT - 1;
    // Scroll screen up
    for (int i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++) {
      VGA_BUFFER[i] = VGA_BUFFER[i + VGA_WIDTH];
    }
    // Clear last line
    for (int i = (VGA_HEIGHT - 1) * VGA_WIDTH; i < VGA_HEIGHT * VGA_WIDTH;
         i++) {
      VGA_BUFFER[i] = (uint16_t)color << 8 | ' ';
    }
  }
  update_cursor();
}

void print_char(char c) {
  if (c == '\n') {
    newline();
  } else if (c == '\b') {
    if (cursor_col > 0) {
      cursor_col--;
      VGA_BUFFER[cursor_row * VGA_WIDTH + cursor_col] =
          (uint16_t)color << 8 | ' ';
      update_cursor();
    }
  } else {
    VGA_BUFFER[cursor_row * VGA_WIDTH + cursor_col] = (uint16_t)color << 8 | c;
    if (++cursor_col >= VGA_WIDTH)
      newline();
    else
      update_cursor();
  }
}

void print_str(const char *str) {
  while (*str)
    print_char(*str++);
}
// Keyboard functions
uint8_t keyboard_read() {
  uint8_t status;
  asm volatile("inb %1, %0" : "=a"(status) : "Nd"(0x64));
  return status;
}

uint8_t get_key() {
  if (!(keyboard_read() & 1))
    return 0;

  uint8_t key;
  asm volatile("inb %1, %0" : "=a"(key) : "Nd"(0x60));
  return key;
}

// Fixed keyboard mapping
char get_ascii(uint8_t scancode) {
  // US QWERTY keyboard mapping
  static const char keymap[128] = {
      0,   0,   '1',  '2',  '3',  '4', '5', '6',  '7', '8', '9', '0',
      '-', '=', '\b', '\t', 'q',  'w', 'e', 'r',  't', 'y', 'u', 'i',
      'o', 'p', '[',  ']',  '\n', 0,   'a', 's',  'd', 'f', 'g', 'h',
      'j', 'k', 'l',  ';',  '\'', '`', 0,   '\\', 'z', 'x', 'c', 'v',
      'b', 'n', 'm',  ',',  '.',  '/', 0,   '*',  0,   ' ', 0};

  if (scancode < sizeof(keymap)) {
    return keymap[scancode];
  }
  return 0;
}

const char int2hex[16] = {'0', '1', '2', '3', '4', '5', '6', '7',
                          '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
void printHex(uint32_t v) {
  char output[17];
  int c = 16;

  if (v == 0) {
    print_str("0x0");
    return;
  }

  while (v != 0) {
    int tmp = v % 16;

    output[c] = int2hex[tmp];

    v /= 16;

    c--;
  }

  print_str("0X");
  for (c = c + 1; c < 17; c++) {
    print_char(output[c]);
  }
}

void printUint(uint32_t v) {
  char output[20];
  int c = 19;

  if (v == 0) {
    print_char(48);
    return;
  }

  while (v != 0) {
    int tmp = v % 10;

    output[c] = tmp + 48;

    v /= 10;

    c--;
  }

  for (c = c + 1; c < 20; c++) {
    print_char(output[c]);
  }
}

UpperMemoryMap *mm;
TUMPPointer *memoryMapPointer;

void checkMemoryMap() {
  uint32_t tmp = (uint32_t)memoryMapPointer->memoryMapPointer;
  mm = (UpperMemoryMap *)tmp;
  int l = memoryMapPointer->memoryMapLength;
  uint64_t totalSize = 0;
  print_str("Memory map has ");
  printUint(l);
  print_str(" entries\n");

  for (int i = 0; i < l; i++) {
    totalSize += mm[i].length;
    printUint(i);
    print_str(". Address:");
    printHex(mm[i].baseAddr);
    print_str(" Size:");
    printUint(mm[i].length);
    print_str(" Type: ");

    if (mm[i].type == 1)
      print_str("Available");
    else if (mm[i].type == 2)
      print_str("Unavailable");
    else
      print_str("???");

    newline();
  }

  print_str("Total ram size: ");
  printUint(totalSize / 1024 / 1024);
  print_str(" MB\n");
}

void hlt() {
  for (;;)
    asm("hlt");
}
DLD *d;
void (*pm2rm)(uint32_t funcAddress);

int readDisk(uint64_t sector) {
  printUint(sector);
  newline();
  d->DAP.LBA = sector;
  pm2rm(d->diskLoadData); // call

  return 1;
}

void preKernelMain() __attribute__((section(".text.entry")));
void preKernelMain() {
  clear_screen();

  print_str("Hello from Arona bootloader stage 2!\n");

  void *p = scanBootTable("TUMP");
  memoryMapPointer = p;

  uint32_t *pm2rmAddr = scanBootTable("PM2RM");
  pm2rm = (void *)*pm2rmAddr;

  if (pm2rm == 0)
    print_str("UUSUSUS\n");

  printHex((uint32_t)pm2rm);

  d = scanBootTable("DLD");

  checkMemoryMap();
  newline();
  if (d->diskLoadData == 0) {
    print_str("SUSSY");
    hlt();
  }

  d->DAP.LBA = 0;
  pm2rm(d->diskLoadData);
  pm2rm(d->diskLoadData);

  initAllocator((void *)0x200000);
  char *buffer = (char *)d->outputAddress;
  int s = readDisk(187);

  s = initSimpleFat32(smalloc, sfree, buffer, readDisk, 512);
  // readDisk(512);
  if (s != 1) {
    print_str("FAT32 driver init failed!\n");
    printUint(s);
  }

  backup();
  while (listDir() != 0) {
    readShortDirName();
    print_str(shortNameRes);
    newline();
  }
  restore();
  readFile("TEST.TXT", (char *)0x300000);
  char *newBuf = (char *)0x300000;
  print_str(newBuf);

  hlt();
}
