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
#pragma once

#include <cstdint>
#define PAGING_PRESENT 0x1
#define PAGING_RW (1 << 1)
#define PAGING_USER_ACCESSIBLE (1 << 2)
#define PAGING_WRITE_THROUGH (1 << 3)
#define PAGING_DISABLE_CACHE (1 << 4)
#define PAGING_ACCESSED (1 << 5)
#define PAGING_DIRTY (1 << 6)
#define PAGING_HUGE_PAGE (1 << 7)
#define PAGING_GLOBAL (1 << 8)
#define PAGING_NO_EXECUTE (1 << 63)

void mapPage();
extern "C" void check(uint64_t);