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

uint64_t pageEntry(uint64_t offset, uint64_t attr) { return (offset | attr); }

extern "C" void loadPML4(uint64_t);

/*
We will map first 10MB as 1:1 page for bootstrap
then map 2G address with 2MB pages for kernel at 0xFFFFFFFF80000000
*/
void mapPage() {
  // mapping address for higher half kernel
  uint64_t *pageAddr = (uint64_t *)0x600000; // place page entries at 6MB
  // 512 PML4, set PML4[511] present
  for (int i = 0; i < 511; i++) {
    pageAddr[i] = pageEntry(0, 0);
  }

  pageAddr[511] =
      pageEntry(0x601000, PAGING_PRESENT | PAGING_RW); // point to PDPT

  // init 512 PDPT, set PDPT[510], PDPT[511] present
  pageAddr += 512;
  for (int i = 0; i < 510; i++) {
    pageAddr[i] = pageEntry(0, 0);
  }
  pageAddr[510] = pageEntry(0x602000, PAGING_PRESENT | PAGING_RW);
  pageAddr[511] = pageEntry(0x603000, PAGING_PRESENT | PAGING_RW);

  // init 1024 PD, all present, huge page
  pageAddr += 512;
  uint64_t offset = 10; // in MB
  for (int i = 0; i < 1024; i++) {
    pageAddr[i] = pageEntry(offset * 0x100000,
                            PAGING_PRESENT | PAGING_RW | PAGING_HUGE_PAGE);
    offset += 2;
  }

  // map first 10MB 1:1 pages for bootstrap
  pageAddr = (uint64_t *)0x600000; // point to PML4

  pageAddr[0] =
      pageEntry(0x604000, PAGING_PRESENT | PAGING_RW); // set PML4[0] present

  pageAddr = (uint64_t *)0x604000; // place PDPT[0] at 0x604000
  // init 512 PDPT
  for (int i = 0; i < 512; i++)
    pageAddr[i] = pageEntry(0, 0);

  pageAddr[0] = pageEntry(0x605000,
                          PAGING_PRESENT | PAGING_RW); // set PDPT[0] present

  // map 10 PD
  pageAddr = (uint64_t *)0x605000; // place PD at 0x605000
  offset = 0;
  for (int i = 0; i < 512; i++) {
    pageAddr[i] = pageEntry(0, 0);
  }

  for (int i = 0; i < 10; i++) {
    pageAddr[i] = pageEntry(offset * 0x100000,
                            PAGING_PRESENT | PAGING_RW | PAGING_HUGE_PAGE);
    offset += 2;
  }

  loadPML4(0x600000);
}