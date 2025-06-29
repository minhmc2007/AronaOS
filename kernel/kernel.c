/*
 * kernel/kernel.c
 * The correct 64-bit kernel code.
 */
void print_char(char c, int row, int col, char color) {
    char* vga_buffer = (char*)0xB8000;
    vga_buffer[(row * 80 + col) * 2] = c;
    vga_buffer[(row * 80 + col) * 2 + 1] = color;
}

void kernel_main() {
    const char *str = "Hello from AronaOS 64-bit!";
    const char color = 0x0A; // Green on black

    for (int i = 0; str[i] != '\0'; i++) {
        // Print the string on the second row of the screen
        print_char(str[i], 1, i, color);
    }

    for (;;) {
        asm ("hlt");
    }
}