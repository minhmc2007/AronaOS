bits 32

initFAT32FS:
    mov ax, word [0x7c0b]
    mov word [FAT32BPB.BPB_BytsPerSec], ax ; byte 11

    mov al, [0x7c0d]
    mov byte [FAT32BPB.BPB_SecPerClus], al ; byte 13

    mov ax, [0x7c0e]
    mov word [FAT32BPB.BPB_RsvdSecCnt], ax ; byte 14

    mov al, [0x7c10]
    mov byte [FAT32BPB.BPB_NumFATs], al    ; byte 16
    
    mov eax, [0x7c20]
    mov dword [FAT32BPB.BPB_TotSec32], eax ; byte 32
    
    ; extended BPB for FAT32
    mov eax, [0x7c24]
    mov dword [FAT32BPB.BPB_FATSz32], eax   ; byte 36

    mov eax, [0x7c2c]
    mov dword [FAT32BPB.BPB_RootClus], eax  ; byte 44

    ; calculate first data sector
    mov eax, 0
    mov al, [FAT32BPB.BPB_NumFATs]
    mov ebx, [FAT32BPB.BPB_FATSz32] 
    mul ebx  ; ebx = FAT32BPB.BPB_NumFATs * FAT32BPB.BPB_FATSz32

    mov ebx, 0
    mov bx, [FAT32BPB.BPB_RsvdSecCnt] ; add with reserved sector
    add eax, ebx

    mov dword [localVar.firstDataSec], eax

    ; NOTE: remember to fill calculation registers with zero, add size when mov for safety:)))
    ; calculate cluster size of FAT32
    mov eax, 0
    mov ebx, 0
    mov al, byte [FAT32BPB.BPB_SecPerClus]
    mov bx, word [FAT32BPB.BPB_BytsPerSec]

    mul bx ; FAT32BPB.BPB_SecPerClus * FAT32BPB.BPB_BytsPerSec
    mov dword [localVar.clusterSize], eax

    ; some test
    mov dword [PM2RMF_CALL_ADDRESS], TEST_F
    call pm2rmf
    
    mov word [0xb8000], 0x0a61

    jmp $

; set edx as sector
loadDir:
    pushad



    popad
    ret

currentDir:
.name:
    times 8 db 0
.ext:
    times 3 db 0
.attr:
    db 0
.fstClusHi:
    dw 0
.fstClusLo:
    dw 0
.fileSize:
    dd 0


localVar:
.firstDataSec:
    dd 0
.clusterSize:
    dd 0

; only need some fields, this to store them
FAT32BPB:
.BPB_BytsPerSec:
    dw 0
.BPB_SecPerClus:
    db 0
.BPB_RsvdSecCnt:
    dw 0
.BPB_NumFATs:
    db 0
.BPB_TotSec32:
    dd 0
.BPB_FATSz32:
    dd 0
.BPB_RootClus:
    dd 0

