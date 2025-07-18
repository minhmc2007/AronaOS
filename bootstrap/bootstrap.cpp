#include <cstdint>

extern "C" {
__attribute__((section(".text.entry"))) int bmain() {
  uint16_t *buffer = (uint16_t *)0xb8000;
  buffer[0] = 0x0a61;
  buffer[1] = 0x0a62;
  buffer[2] = 0x0a63;
  for (;;) {
  }
}
}
