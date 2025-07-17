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

    ; calculate BPB_BytsPerSec / 512
    mov ebx, 512
    mov eax, 0
    mov ax, [FAT32BPB.BPB_BytsPerSec]
    div ebx
    mov dword [localVar.FAT32BD512], eax

    ; test

    mov eax, 0
    mov eax, 4
    mov ebx, 0
    call loadCluster

    mov al, byte [DISK_READ_OUTPUT_ADDRESS]
    mov ah, 0xfa
    mov word [0xb8000], ax 

    jmp $

; set edx as sector
loadDir:
    pushad



    popad
    ret

; set eax as cluster, ebx as index
; -> readSector(firstDataSec + (cluster - 2) * secPerClus + index)
loadCluster:
    pushad
    mov ecx, 2
    sub eax, ecx ; eax -= 2

    mov ecx, 0
    mov cl, byte [FAT32BPB.BPB_SecPerClus]
    mul cl ; eax *= cx (cluster * BPB_SecPerClus)

    add eax, dword [localVar.firstDataSec] ; eax += localVar.firstDataSec
    
    add eax, ebx ; eax += index
    
    mov edx, eax
    call loadSec

    popad
    ret

; set edx as sector
loadSec:
    pushad
    mov dword [.LBA], edx

    ; pass number of 512 bytes sectors need to read to DiskLoad.asm
    mov ax, word [localVar.FAT32BD512]
    mov word [DLD.sector], ax ; dont need to mind about type
    
    ; load that same value to cx
    mov cx, word [localVar.FAT32BD512] 

    mov eax, 0
    ; calculate sector offset
    mov eax, dword [.LBA]
    mul cx ; eax = edx; eax(sector offset ) *= cx
    
    mov dword [DLD.LBA], eax ; DLD.LBA = edx = sector to read

    mov dword [PM2RMF_CALL_ADDRESS], diskLoadData
    call pm2rmf 
    
    popad
    ret
.LBA:
    dd 0

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
.FAT32BD512: ; FAT32 BytsPerSec / 512
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

