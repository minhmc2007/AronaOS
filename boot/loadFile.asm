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

; pm2rm but modified...
bits 32
pm2rmf:
    pushad
    cli

    lgdt [GDTR16]

    jmp (GDT16.CODE16-GDT16):.pm16
bits 16
.pm16:
    mov ax, GDT16.DATA16-GDT16
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
.turnOffPE:
    mov eax, cr0
    and eax, 0xfffffffe
    mov cr0, eax

    jmp 0:rm
bits 16  
rm:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    lidt [IDTR16]
    sti

    ; maybe we shouldn't change esp
    ; mov esp, 0
    ; mov ebp, 0
    ; mov sp, word [RM_STACK_ADDRESS]
    ; mov bp, sp

.pm2rmCaller:
    call [PM2RMF_CALL_ADDRESS]

.rm2pm:
.enterProtectedMode:
    cli
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp CODE_SEG_32:.protectedModeStart

bits 32
.protectedModeStart:
    mov ax, DATA_SEG_32
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    popad

    ret ; return

PM2RMF_CALL_ADDRESS:
    dd 0

bits 16
TEST_F:
    mov si, tfs
    call print_string
    ret


tfs: db "OKAY IM REAL (MODE)", 13, 10 , 0

IDTR16:
    dw 0x3FF
    dd 0x0

GDTR16:
    dw GDT16.END - GDT16 - 1
    dd GDT16

GDT16:
    .NULL:
        dq 0
    .CODE16:
        dw 0xffff     ; low limit
        dw 0          ; low base
        db 0          ; mid base
        db 0b10011010 ; access bit
        db 0b00000000 ; flags + high limit
        db 0          ; high base
    .DATA16:
        dw 0xffff     ; low limit
        dw 0          ; low base
        db 0          ; mid base
        db 0b10010010 ; access bit
        db 0b11000000 ; flags + high limit
        db 0          ; high base
    .END: