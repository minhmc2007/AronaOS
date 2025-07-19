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
#include "paging/paging.hpp"
#include <cstdint>

extern "C" {
__attribute__((section(".text.entry"))) int bmain() {
  uint16_t *buffer = (uint16_t *)0xb8000;
  buffer[0] = 0x0a61;
  buffer[1] = 0x0a62;
  buffer[2] = 0x0a63;

  mapPage();
  buffer[3] = 0x0a69;
  uint16_t *a = (uint16_t *)0xa00000;
  *a = 0x0a70;
  a = (uint16_t *)0xFFFFFFFF80000000;
  buffer[4] = *a;

  for (;;) {
  }
}
}
