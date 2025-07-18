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
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

uint32_t getFileSize(FILE *f) {
  fseek(f, 0, SEEK_END);
  uint32_t res = ftell(f);
  fseek(f, 0, SEEK_SET);
  return res;
}

int main(int argc, char **argv) {
  if (argc < 2)
    return 0;

  if (strcmp(argv[1], "install-bios") == 0) {
    if (argc < 4)
      return -1;

    FILE *f = fopen(argv[2], "r+");
    if (f == NULL)
      return -1;

    FILE *mbr = fopen(argv[3], "r");
    if (f == NULL)
      return -1;

    char *buffer = malloc(getFileSize(mbr));
    uint64_t s = fread(buffer, 1, getFileSize(mbr), mbr);

    printf("%ld\n", s);
    for (uint32_t i = 0; i < getFileSize(mbr); i++) {
      fseek(f, 90 + i, SEEK_SET);
      fputc(buffer[i], f);
    }

    fclose(f);
    fclose(mbr);

    free(buffer);
  }

  return 0;
}