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

    ; calculate dir per sec
    mov eax, 0
    mov ax, word [FAT32BPB.BPB_BytsPerSec]
    mov ebx, 32
    div ebx

    mov dword [localVar.DirPerSec], eax
    ; test

    mov eax, 0
    mov eax, [FAT32BPB.BPB_RootClus]
    mov ebx, 0
    call loadCluster

    ret

;eax = address
; caller should backup clus
readFile:
    pushad

    mov dword [.address], eax ; save
    mov byte [.index], 0

    .loop:
        mov eax, dword [loadCluster.currentClus]
        mov ebx, 0
        mov bl, byte [.index]
        call loadCluster

        mov ecx, DISK_READ_OUTPUT_ADDRESS
        mov ebx, dword [.address]
        mov edx, 0
        mov dx, word [FAT32BPB.BPB_BytsPerSec]
        call fmemcpy


        add dword [.movSize], edx; add by Byt per sec
        add dword [.address], edx

        ; cmp with sec per clus
        mov al, byte [FAT32BPB.BPB_SecPerClus]
        inc byte [.index]
        cmp byte [.index], al
        jne .loop

        mov eax, dword [currentDir.fileSize] ; check if end of clus
        cmp eax, dword [.movSize]
        jg .increaseClus

    popad
    ret
.increaseClus:
    mov eax, [loadCluster.currentClus]
    call readFAT
    cmp eax, 0xffffff7
    jge .error
    mov byte [.index], 0
    mov ebx, 0
    call loadCluster 
    jmp .loop
.error:
    mov esi, .ers
    call println
    jmp $
.ers:
    db "BAD FAT32", 0
.backupClus:
    dd 0
.movSize:
    dd 0
.address:
    dd 0
.index:
    db 0

; eax = index
; eax = return code
readFAT:
    pushad

    ; index * 4
    mov ebx, 4
    mul ebx

    ; offset = index * 4 / bytsPerSector
    mov cx, word [FAT32BPB.BPB_BytsPerSec]
    div cx
    ; offset[i], i = index * 4 % bytsPerSector
    mov ebx, edx 

    mov edx, eax
    add dx, word [FAT32BPB.BPB_RsvdSecCnt]
    call loadSec

    mov eax, dword [DISK_READ_OUTPUT_ADDRESS + ebx]
    mov dword [.returnValue], eax

    call loadCluster.checkCurrent

    popad
    mov eax, dword [.returnValue]
    and eax, 0x0fffffff ; remove last 4 bits
    ret
.returnValue:
    dd 0
.FAT32:
    dd 0

; eax = name
; result = 0 -> not found
findDir:
    pusha
    mov ecx, 0 ; use ecx as counter
    mov dword [loadDir.currentIndex], 0
    .loop:
        call loadDir
        inc ecx

        cmp dword [loadDir.result], 0
        je .end

        ;check if DIR_NAME[0] == 0xe5
        mov bl, byte [currentDir.name]
        cmp bl, 0xe5
        je .loop ; ignore it

        mov esi, currentDir.name
        call println

        ; cmp if equal
        mov ebx, currentDir.name
        call astrcmp
        cmp dword [astrcmp.result], 1
        je .found

        ; cmp with Dir per sec
        cmp ecx, dword [localVar.DirPerSec]
        jne .loop
    .end:
        mov dword [.result], 0
        popa
        ret
    .found:
        mov dword [.result], 1
        popa
        ret
.result:
    dd 0

; if result = 0 -> no more dir, else result = 1
; caller should set loadDir.currentIndex = 0 for first call
loadDir:
    pushad

    ; calculate dir address
    mov eax, dword [.currentIndex]
    mov ebx, 32
    mul ebx
    add eax, DISK_READ_OUTPUT_ADDRESS

    ; inc currentIndex
    mov ecx, dword [.currentIndex]
    inc ecx
    mov dword [.currentIndex], ecx

    ; check the first byte of dir entry, caller should check if the first bytes 0xe5 to ignore
    mov dl, byte [eax]
    cmp dl, 0x00 
    je .noMoreResult

    ; load name
    call .nstrcpy
    ;load ext
    call .enstrcpy

    ; load attr
    mov dl, byte [eax + 11]
    mov byte [currentDir.attr], dl

    ; load first clus HI/LO
    mov dx, word [eax + 20]
    mov word [currentDir.fstClusHi], dx
    mov dx, word [eax + 26]
    mov word [currentDir.fstClusLo], dx
    
    ;load file size
    mov edx, dword [eax + 28]
    mov dword [currentDir.fileSize], edx

.end:
    mov dword [.result], 1
    popad
    ret
; copy till ecx = 8 or byte = 0x20 (space)
.nstrcpy:
    mov ecx, 0
    .loop:
        mov dl, byte [eax + ecx]
        cmp dl, 0x20
        je .endLoop

        mov byte [currentDir.name + ecx], dl
        inc ecx

        cmp ecx, 8
        je .endLoop
        
        jmp .loop
    .endLoop:
        mov byte [currentDir.name +  ecx], 0 ; add zero at the end
        ret
; copy till ecx = 3 or byte = 0x20 (space)
.enstrcpy:
    mov ecx, 0
    .eloop:
        mov dl, byte [eax + 8 + ecx]
        cmp dl, 0x20
        je .eendLoop

        mov byte [currentDir.ext + ecx], dl

        inc ecx
        cmp ecx, 3
        je .eendLoop

        jmp .eloop
    .eendLoop:
        mov byte [currentDir.ext +  ecx], 0 ; add zero at the end
        ret
    
.noMoreResult:
    mov dword [.result], 0
    popad
    ret
.result:
    dd 0
.currentIndex:
    dd 0


; set eax as cluster, ebx as index
; -> readSector(firstDataSec + (cluster - 2) * secPerClus + index)
loadCluster:
    pushad
    mov dword [.currentClus], eax
    mov ecx, 2
    sub eax, ecx ; eax -= 2

    mov ecx, 0
    mov cl, byte [FAT32BPB.BPB_SecPerClus]
    mul cl ; eax *= cx (cluster * BPB_SecPerClus)

    add eax, dword [localVar.firstDataSec] ; eax += localVar.firstDataSec
    
    add eax, ebx ; eax += index
    
    mov dword [.currentLBA], eax
    mov edx, eax
    call loadSec

    popad
    ret
.currentLBA:
    dd 0
.currentClus:
    dd 0
.checkCurrent:
    pushad

    ; check if LoadSec.LBA = .currentLBA
    mov eax, dword [loadSec.LBA]
    mov ebx, dword [.currentLBA]
    cmp eax, ebx
    je .endCheck

    mov edx, dword [.currentLBA]
    call loadSec

.endCheck:
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
    times 9 db 0
.ext:
    times 4 db 0
.attr:
    db 0
.fstClus:
.fstClusLo:
    dw 0
.fstClusHi:
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
.DirPerSec:
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

