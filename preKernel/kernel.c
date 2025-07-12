/*
 * kernel/kernel.c
 * 64-bit kernel with shell
 */
#include <stdalign.h>
#include <stdint.h>

#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define CMD_BUFFER_SIZE 256

static uint16_t *const VGA_BUFFER = (uint16_t *)0xB8000;
static int cursor_row = 0;
static int cursor_col = 0;
static uint8_t color = 0x0A; // Green on black

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

// Shell functions
void shell_execute(const char *cmd) {
  if (custom_strcmp(cmd, "help") == 0) {
    print_str("Available commands: help, about, echo, clear\n");
  } else if (custom_strcmp(cmd, "about") == 0) {
    print_str("AronaOS 64-bit\nCreated by minhmc2007 and thisisaname1928\n");
  } else if (custom_strncmp(cmd, "echo ", 5) == 0) {
    print_str(cmd + 5);
    print_char('\n');
  } else if (custom_strcmp(cmd, "clear") == 0) {
    clear_screen();
  } else if (*cmd) {
    print_str("Unknown command: ");
    print_str(cmd);
    print_str("\nType 'help' for commands\n");
  }
}

void shell() {
  char cmd_buffer[CMD_BUFFER_SIZE];
  int cmd_index = 0;

  print_str("AronaOS Shell\nType 'help' for commands\n");

  while (1) {
    print_str("\nAronaOS> ");
    cmd_index = 0;
    cmd_buffer[0] = '\0';

    // Read command
    while (1) {
      uint8_t scancode = get_key();
      if (!scancode)
        continue;

      // Handle special keys
      if (scancode == 0x1C) { // Enter
        print_char('\n');
        break;
      } else if (scancode == 0x0E) { // Backspace
        if (cmd_index > 0) {
          print_char('\b');
          cmd_index--;
        }
        continue;
      }

      // Convert scancode to ASCII
      char c = get_ascii(scancode);
      if (c) {
        print_char(c);
        if (cmd_index < CMD_BUFFER_SIZE - 1) {
          cmd_buffer[cmd_index++] = c;
        }
      }
    }

    // Execute command
    cmd_buffer[cmd_index] = '\0';
    shell_execute(cmd_buffer);
  }
}

void kernel_main() __attribute__((section(".text.entry")));
void kernel_main() {
  clear_screen();
  print_str("Hello from AronaOS 64-bit!\n");
  shell();

  for (;;)
    asm("hlt");
}
