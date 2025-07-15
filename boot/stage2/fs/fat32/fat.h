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
#ifndef FAT_H
#define FAT_H

#include <stdint.h>
typedef struct {
  char BS_jmpboot[3];
  char BS_OEMName[8];
  uint16_t BPB_BytsPerSec;
  uint8_t BPB_SecPerClus;
  uint16_t BPB_RsvdSecCnt;
  uint8_t BPB_NumFATs;
  uint16_t BPB_RootEntCnt; // not use
  uint16_t BPB_TotSec16;
  uint8_t BPB_Media;
  uint16_t BPB_FATSz16; // Number of sectors per FAT (Only on Fat 12, fat 16)
  uint16_t BPB_SecPerTrk;
  uint16_t BPB_NumHeads;
  uint32_t BPB_HiddSec;
  uint32_t BPB_TotSec32;
  // EXTENDED BPB
  uint32_t BPB_FATSz32;
  uint16_t BPB_ExtFlags;
  uint16_t BPB_FSVer;
  uint32_t BPB_RootClus;
  uint16_t BPB_FSInfo;
  uint16_t BPB_BkBootSec;
  char reserved[12];
  uint8_t BS_DrvNum;
  uint8_t BS_Reserved1;
  uint8_t BS_BootSig;
  uint32_t BS_VolID;
  char BS_VolLab[11];
  char fat32SystemIDString[8];
  char fat32BootCode[422];
} __attribute__((packed)) BiosParamaterBlock;

#define FIRST_SIGNATURE 0x41615252
#define SECCOND_SIGNATURE 0x61417272
#define TRAIL_SIGNATURE 0xAA550000
#define NO_HINT 0xFFFFFFFF
#define FAT32_FSI_LeadSig 0x28
#define FAT32_SIGNATURE2 0x29

#define FAT32_NO_MORE_CLUSTER 123
#define FAT32_BAD_CLUSTER 124
#define FAT32_FREE_CLUSTER 125
#define FAT32_NEXT_CLUSTER_PTR 127

#define FAT32_READONLY 0x01
#define FAT32_HIDDEN 0x02
#define FAT32_SYSTEM 0x04
#define FAT32_VOLUME_ID 0x08
#define FAT32_DIRECTORY 0x10
#define FAT32_ARCHIVE 0x20
#define FAT32_LONG_FILE_NAME_ENTRY                                             \
  FAT32_READONLY | FAT32_HIDDEN | FAT32_SYSTEM | FAT32_VOLUME_ID

#define FAT32_VERIFY_FAILED 0
#define FAT32_TOO_SIMPLE_NOT_SUPPORT -1
#define FAT32_READ_FAIL -2
#define FAT32_ERROR_NO_HINT -4
#define FAT32_DIRECTORY_FREE -198

typedef struct __attribute__((packed)) {
  uint32_t FSI_LeadSig;
  char reserved[480];
  uint32_t FSI_StrucSig;
  uint32_t FSI_Free_Count;
  uint32_t FSI_Nxt_Free;
  char reserved1[12];
  uint32_t FSI_TrailSig;
} FSInfo;

typedef struct __attribute__((packed)) {
  uint8_t LDIR_Ord;
  uint16_t LDIR_Name1[5];
  uint8_t LDIR_Attr;
  uint8_t LDIR_Type;
  uint8_t LDIR_Chksum;
  uint16_t LDIR_Name2[6];
  uint16_t reserved;
  uint16_t LDIR_Name3[2];
} longFileNameExt;

typedef struct __attribute__((packed)) {
  char DIR_Name[8];
  char DIR_Ext[3];
  uint8_t DIR_Attr;
  uint8_t reserved;
  uint8_t DIR_CrtTimeTenth;
  uint16_t DIR_CrtTime;
  uint16_t DIR_CrtDate;
  uint16_t DIR_LstAccDate;
  uint16_t DIR_FstClusHI;
  uint16_t DIR_WrtTime;
  uint16_t DIR_WrtDate;
  uint16_t DIR_FstClusLO;
  uint32_t DIR_FileSize;
} FAT32Dir;

#define LONG_FILE_NAME_ATTRIBUTE 0x0f

int initSimpleFat32(void *imalloc, void *ifree, char *readBuffer,
                    void *readFuncPtr, uint32_t sizeOfBuffer);

int verifyFat32();
// return 1 if found, 0 if NOTFOUND, -1 for bad file
int readFile(const char *INP, char *buffer);
uint32_t readFileSize(const char *INP);
int openFolder(const char *INP);
int listDir();
void readShortDirName();
int checkAttrInfo(uint8_t attr, uint8_t attrType);

extern FAT32Dir resultDir;
extern char shortNameRes[13];

#endif