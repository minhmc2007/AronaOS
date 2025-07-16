/*
   Copyright 2025 QUOC TRUNG NGUYEN

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
#include "fat.h"
#include <stdint.h>
#include <string.h>

char buffer[512];

char *readBuffer;
void *(*iMalloc)(uint32_t);
void (*iFree)(void *, uint32_t size);
uint32_t bufferSize;
int (*readDiskSimpleFat32)(uint32_t sector) = 0;
int isInitialized = 0;
uint32_t currentSector = 0;

BiosParamaterBlock BPB;
FSInfo infoFS;
uint32_t clusterSize;
uint32_t numberOfSectors;
uint32_t fatOffset;
uint32_t firstDataSector;

// bufferSize should be bigger than 512 bytes
#define IS_INITALIZED(val)                                                     \
  if (isInitialized != 1)                                                      \
    return val;                                                                \
  if (bufferSize < 512)                                                        \
  return val

#define readAndCheck(sector, val)                                              \
                                                                               \
  if (!readHelper(sector))                                                     \
    return val;

int readHelper(uint32_t sector) {
  if (currentSector != sector) {
    currentSector = sector;
    return readDiskSimpleFat32(sector);
  }
  return 1;
}

uint32_t currentCluster = 0;
int readCluster(uint32_t index) {
  readAndCheck(firstDataSector + BPB.BPB_SecPerClus * (index - 2), -1);
  currentCluster = index;
  return 1;
}

uint32_t readFAT32(uint32_t Offset, uint32_t index) {
  uint32_t sector = index * 4 / BPB.BPB_BytsPerSec;
  uint32_t base = index * 4;
  readAndCheck(Offset + sector, 0);

  uint32_t *ptr = (uint32_t *)((char *)readBuffer + base);
  return *ptr & 0x0fffffff; // trunc out last 4 bit
}

int parseFAT32Entry(uint32_t f) {

  if (f >= 0x0ffffff8)
    return FAT32_NO_MORE_CLUSTER;

  if (f == 0x0ffffff7)
    return FAT32_BAD_CLUSTER;

  if (f == 0)
    return FAT32_FREE_CLUSTER;

  return FAT32_NEXT_CLUSTER_PTR;
}

int getFSInfo() {
  readAndCheck(BPB.BPB_FSInfo, FAT32_READ_FAIL);

  FSInfo *f = (FSInfo *)readBuffer;

  return 1;
}

int checkAttrInfo(uint8_t attr, uint8_t attrType) {
  return (attr & attrType) == attrType;
}

int parseDirEntry(uint32_t cluster) {
  readCluster(cluster);

  FAT32Dir *d = (FAT32Dir *)readBuffer;
  if (d->DIR_Name[0] == 0) {
    return -1;
  }

  if ((uint8_t)d->DIR_Name[0] == 0xe5) {
    if (checkAttrInfo(d->DIR_Attr, LONG_FILE_NAME_ATTRIBUTE)) {
    }
  }

  return 1;
}

#define CHECK_RESULT(retVal)                                                   \
  if (retVal != 1)                                                             \
    return retVal;

#define PARSE_RESULT_LFN 1928
#define PARSE_RESULT_DIR 1829
#define PARSE_RESULT_FILE 928

typedef struct {
  int type;
  void *namePtr;
} ParseResult;

FAT32Dir resultDir;
ParseResult parseResult;

extern void print_str(const char *);
extern void print_char(const char);
void open(uint32_t cluster);
int parseDir(uint32_t index) {
  FAT32Dir *d =
      (FAT32Dir *)((char *)readBuffer + (index * (uint32_t)sizeof(FAT32Dir)));
  memcpy(&resultDir, d, sizeof(FAT32Dir));
  // resultDir = *d; // static save

  if ((uint8_t)d->DIR_Name[0] == 0xe5 ||
      (uint8_t)d->DIR_Name[0] == 0) // Dir0 free
    return FAT32_DIRECTORY_FREE;

  // should add a handle for byte 0x05

  if (checkAttrInfo(d->DIR_Attr, LONG_FILE_NAME_ATTRIBUTE)) {
    parseResult.type = LONG_FILE_NAME_ATTRIBUTE;

    return LONG_FILE_NAME_ATTRIBUTE;
  }

  if (checkAttrInfo(d->DIR_Attr, FAT32_DIRECTORY)) { // a dir
    parseResult.type = PARSE_RESULT_DIR;

    return PARSE_RESULT_DIR;
  }

  parseResult.type = PARSE_RESULT_FILE;

  return PARSE_RESULT_FILE;
}

uint32_t currentIndex;
void open(uint32_t cluster);

uint32_t backUpCluster;
void backup() { backUpCluster = currentCluster; }
void restore() { open(backUpCluster); }

/* get data from current readBuffer
if return 0 mean no more entries
if return 1 mean there are some
should backup opening cluster per call
*/
int listDir() {
  int s = parseDir(currentIndex);

  if (s == FAT32_DIRECTORY_FREE) {
    currentIndex = 0; // reset read index
    return 0;
  }

  if (currentIndex >= 15) {
    if (parseFAT32Entry(readFAT32(fatOffset, currentCluster)) ==
        FAT32_NO_MORE_CLUSTER) { // check FAT32 for next cluster
      currentIndex = 0;
      return 0;
    } else { // if there is more
      open(readFAT32(fatOffset, currentCluster));
      return 1;
    }
  } else {

    currentIndex++;
    return 1;
  }
  return 0;
}

// open a dir by cluster
void open(uint32_t cluster) {
  readCluster(cluster);
  currentIndex = 0;
}

char shortNameRes[13];
void readShortDirName() {
  if (checkAttrInfo(resultDir.DIR_Attr, FAT32_DIRECTORY)) {
    int i;
    for (i = 0; i < 8; i++) {
      if (resultDir.DIR_Name[i] != 0x20) {
        shortNameRes[i] = resultDir.DIR_Name[i];
      } else {
        break;
      }
    }

    shortNameRes[i] = 0;
    return;
  } else { // a filename
    int i;
    for (i = 0; i <= 8; i++) {
      if (i == 8)
        break; // to add a dot

      if (resultDir.DIR_Name[i] != 0x20) {
        shortNameRes[i] = resultDir.DIR_Name[i];
      } else {
        break;
      }
    }

    if (resultDir.DIR_Ext[0] != 0x20) { // if file have extension
      shortNameRes[i] = '.';
      i++;
    }

    // get file extension
    for (int j = 0; j < 3; j++) {
      if (resultDir.DIR_Ext[j] != 0x20) {
        shortNameRes[i] = resultDir.DIR_Ext[j];
        i++;
      } else
        break;
    }

    shortNameRes[i] = 0;
  }
}

int sstrcmp(const char *s1, const char *s2) {
  int i = 0;
  while (s1[i] != 0 && s2[i] != 0) {
    if (s1[i] != s2[i])
      break;

    i++;
  }

  return s1[i] == s2[i];
}

int openFolder(const char *INP) {
  backup();
  while (listDir() != 0) {
    if (checkAttrInfo(resultDir.DIR_Attr,
                      FAT32_DIRECTORY)) { // check if its a folder

      readShortDirName();
      if (sstrcmp(shortNameRes, INP)) {
        uint32_t nextClus =
            (resultDir.DIR_FstClusHI << 16) | resultDir.DIR_FstClusLO;
        if (nextClus == 0)
          nextClus = 2; // back to root

        open(nextClus); // open dir cluster
        return 1;
      }
    }
  }

  restore(); // failed then restore
  return 0;
}

void smemcpy(char *dest, char *src, uint32_t s) {
  for (uint32_t i = 0; i < s; i++) {
    dest[i] = src[i];
  }
}

uint32_t readFileSize(const char *INP) {
  backup();
  while (listDir() != 0) {
    if (!checkAttrInfo(resultDir.DIR_Attr, FAT32_DIRECTORY) &&
        !checkAttrInfo(resultDir.DIR_Attr,
                       LONG_FILE_NAME_ATTRIBUTE)) { // check if its a file

      readShortDirName();
      if (sstrcmp(shortNameRes, INP)) {
        uint32_t res = resultDir.DIR_FileSize;
        restore();
        return res;
      }
    }
  }

  restore(); // failed then restore
  return 0;
}

// return 1 if found, 0 if NOTFOUND, -1 for bad file
int readFile(const char *INP, char *buffer) {
  int isFound = 0;
  uint32_t fileSize = 0;
  uint32_t clus = 0;
  backup();
  while (listDir() != 0) {
    if (!checkAttrInfo(resultDir.DIR_Attr, FAT32_DIRECTORY) &&
        !checkAttrInfo(resultDir.DIR_Attr,
                       LONG_FILE_NAME_ATTRIBUTE)) { // check if its a file

      readShortDirName();
      if (sstrcmp(shortNameRes, INP)) {
        clus = (resultDir.DIR_FstClusHI << 16) | resultDir.DIR_FstClusLO;
        isFound = 1;
        fileSize = resultDir.DIR_FileSize;
        break;
      }
    }
  }

  restore();
  if (!isFound)
    return 0;

  uint32_t readSize = 0;

  while (readSize < fileSize) {
    // read current cluster
    int s = readCluster(clus);
    if (!s) {
      return 0;
    }

    if ((fileSize - readSize) < 512)
      smemcpy((char *)buffer + readSize, readBuffer,
              fileSize - readSize); // copy remain only
    else
      smemcpy((char *)buffer + readSize, readBuffer, 512); // copy all to dest

    if (readSize >= fileSize)
      break;

    uint32_t nextClus = parseFAT32Entry(readFAT32(fatOffset, clus));

    if (nextClus == FAT32_BAD_CLUSTER) {
      return -1;
    } else if (nextClus == FAT32_NO_MORE_CLUSTER) {
      return 1;
    } else
      clus = nextClus;

    readSize += 512;
  }

  return 1;
}

extern void printHex(uint32_t);

int verifyFat32() {
  readDiskSimpleFat32(0);
  currentSector = 0;
  readAndCheck(0, 0);
  BiosParamaterBlock *b = (BiosParamaterBlock *)readBuffer;

  BPB = *b;

  // get number of sectors
  if (BPB.BPB_TotSec16 == 0)
    numberOfSectors = BPB.BPB_TotSec32;
  else
    numberOfSectors = BPB.BPB_TotSec16;

  fatOffset = BPB.BPB_RsvdSecCnt;

  if (BPB.BPB_BytsPerSec != 512)
    return FAT32_TOO_SIMPLE_NOT_SUPPORT; // this only handle 512 bytes sector
  clusterSize = BPB.BPB_SecPerClus * BPB.BPB_BytsPerSec;
  int s = getFSInfo();
  if (s != 1)
    return s;
  firstDataSector = fatOffset + BPB.BPB_FATSz32 * BPB.BPB_NumFATs;

  open(3); // mount root cluster

  return 1;
}

int initSimpleFat32(void *imalloc, void *ifree, char *rB, void *readFuncPtr,
                    uint32_t sizeOfBuffer) {
  readBuffer = rB;
  readDiskSimpleFat32 = readFuncPtr;
  bufferSize = sizeOfBuffer;

  iMalloc = imalloc;
  iFree = ifree;

  isInitialized = verifyFat32();
  return isInitialized;
}
