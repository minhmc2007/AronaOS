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
#include <cstdint>
#pragma once

typedef struct __attribute__((packed)) {
  char magic[4];
  uint8_t bit;
  uint8_t endian;
  uint8_t headerVersion;
  uint8_t ABI;
  uint8_t ABIVersion;
  char reserved[7];
  uint16_t type;
  uint16_t instructionSet;
  uint32_t ELFVersion;
  uint64_t programEntryOffset;
  uint64_t programHeaderTableOffset;
  uint64_t sectionHeaderTableOffset;
  uint32_t flags;
  uint16_t headerSize;
  uint16_t programHeaderSize;
  uint16_t numberOfProgramHeaderTables;
  uint16_t sectionHeaderEntrySize;
  uint16_t numberOfSectionHeaderEntry;
  uint16_t indexOfNameSectionHeader;
} ELFHeader;

typedef struct __attribute__((packed)) {
  uint32_t type;
  uint32_t flags;
  uint64_t offset;
  uint64_t virtualAddress;
  uint64_t physicalAddress;
  uint64_t fileSize;
  uint64_t memSize;
  uint64_t align;
} ProgramHeader;

typedef struct __attribute__((packed)) {
  uint32_t name;
  uint32_t type;
  uint64_t flags;
  uint64_t address;
  uint64_t offset;
  uint64_t size;
  uint32_t link;
  uint32_t info;
  uint64_t addressAlign;
  uint64_t entSize;
} SectionHeader;