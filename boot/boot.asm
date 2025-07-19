org 0x7e00
bits 16
STAGE2_ADDRESS equ 0x8000
PMM_STACK_ADDRESS equ 0x1F0000

start:
    ; Save boot drive
    mov [boot_drive], dl
    mov word [RM_STACK_ADDRESS], sp ; save realmode stack 
    ; set color
    mov ah, 0xb
    mov bh, 0x0
    mov bl, 0xf5
    int 0x10
    ; clear screen by resetting video mode
    mov ah, 0xf
    int 0x10
    mov ah, 0x00
    int 0x10

    mov si, TEST
    call print_string

    ; load at 0x8000
    mov ax, 0
    mov es, ax
    mov bx, STAGE2_ADDRESS

    ; Load stage2 from disk
    mov ah, 0x02
    mov al, 29        ; load 29 sector
    mov ch, 0         ; Cylinder 0
    mov cl, 4         ; Sector 4 (second sector after FSInfo)
    mov dh, 0         ; Head 0
    mov dl, byte [boot_drive]
    int 0x13
    jc disk_error

    cmp al, 29         ; Check if bios read 29 sectors
    jne disk_error

    mov al, [boot_drive]
    mov [DLD.bootDrive], al

    call getUpperMemoryMap
   
    ; Enter 32-bit protected mode
    call enter_protected_mode


TEST: db "starting bootloader", 13, 10, 0

RM_STACK_ADDRESS:
    dw 0

print_string:
    pusha
    push ax
    push si
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    popa
    pop si
    pop ax
    ret

disk_error:
    mov si, error_msg
    call print_string
    hlt
    jmp $

%include "boot/pm2rm.asm"
%include "boot/loadFile.asm"

boot_drive      db 0
error_msg       db "DRE", 13, 10, 0

db "E"

%include "boot/getMemoryMap.asm"
[bits 16]
enter_protected_mode:
    cli
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to flush prefetch queue and enter protected mode
    jmp CODE_SEG_32:protected_mode_start

%include "boot/print.asm"
%include "boot/string.asm"
; 32-bit protected mode code
[BITS 32]
protected_mode_start:
    ; Set up data segments
    mov ax, DATA_SEG_32
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov dword [println.dest], 0xb8000
    mov esi, initMsg
    call println

    call initFAT32FS

    ; search for BIN
    mov eax, bootFolder
    call findDir

    cmp dword [findDir.result], 1
    je .found

    jmp $

    .found:
        mov esi, foundMsg
        call println
        mov eax, dword [currentDir.fstClus]
        mov ebx, 0
        call loadCluster
        mov eax, bootstrap
        call findDir
        cmp dword [findDir.result], 1
        je .foundBS
        
        jmp $
    .foundBS:
        mov esi, foundMsg
        call println
        mov eax, dword [currentDir.fileSize]
        mov dword [BSFS.bootstrapSize], eax
        mov eax, dword [loadCluster.currentClus]
        mov dword [.backupClus], eax
        mov eax, [currentDir.fstClus]
        call loadCluster
        mov eax, 0x200000
        call readFile

        mov eax, dword [.backupClus]
        mov ebx, 0
        call loadCluster
        
        ; load kernel
        mov eax, kernel
        call findDir
        mov eax, dword [currentDir.fileSize]
        mov dword [BSFS.kernelSize], eax
        mov eax, dword [currentDir.fstClus]
        call loadCluster
        mov eax, 0xa00000
        call readFile

        call setupLongMode

        jmp $
.backupClus:
    dd 0

initMsg: db "init fat32 simple driver!", 0
bootFolder: db "BOOT", 0
bootstrap: db "BS", 0
foundMsg: db "found folder!", 0
kernel: db "KERNEL", 0

; BSFS table
BSFS: db "BSFS"
.bootstrapSize:
    dd 0
.kernelSize:
    dd 0

setupLongMode:
    ; Set up paging for long mode
    call setup_paging_32

    ; Load 64-bit GDT
    lgdt [gdt64_descriptor]

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Set long mode bit in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Jump to long mode
    jmp CODE_SEG_64:long_mode_start

setup_paging_32:
    ; Clear page tables area (16KB) at 0x100000
    mov edi, 0x100000
    mov ecx, 4096
    xor eax, eax
    rep stosd

    ; Set up PML4
    mov edi, 0x100000
    mov dword [edi], 0x101003  ; Point to PDP, present + writable

    ; Set up PDP
    mov edi, 0x101000
    mov dword [edi], 0x102003  ; Point to PD, present + writable

    ; Set up PD - identity map first 1GB
    mov edi, 0x102000
    mov ecx, 512
    mov eax, 0x00000083        ; Present + writable + 2MB pages
.map_loop:
    mov dword [edi], eax
    mov dword [edi + 4], 0
    add edi, 8
    add eax, 0x200000
    loop .map_loop

    ; Load CR3 with PML4 address
    mov eax, 0x100000
    mov cr3, eax
    ret

; 64-bit long mode code
[BITS 64]
long_mode_start:
    ; Set up segments for long mode
    mov ax, DATA_SEG_64
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x1a0000 ; set as LONGMODE STACK

    ; Jump to bootstrap
    jmp 0x200000

; 32-bit GDT
[BITS 16]
gdt_32:
    dq 0                        ; Null descriptor
CODE_SEG_32 equ $ - gdt_32
    dw 0xFFFF                   ; Limit 15:0
    dw 0x0000                   ; Base 15:0
    db 0x00                     ; Base 23:16
    db 0x9A                     ; Access byte
    db 0xCF                     ; Flags + Limit 19:16
    db 0x00                     ; Base 31:24
DATA_SEG_32 equ $ - gdt_32
    dw 0xFFFF                   ; Limit 15:0
    dw 0x0000                   ; Base 15:0
    db 0x00                     ; Base 23:16
    db 0x92                     ; Access byte
    db 0xCF                     ; Flags + Limit 19:16
    db 0x00                     ; Base 31:24

gdt_descriptor:
    dw $ - gdt_32 - 1           ; Size
    dd gdt_32                   ; Address

; 64-bit GDT
gdt_64:
    dq 0                        ; Null descriptor
CODE_SEG_64 equ $ - gdt_64
    dw 0                        ; Limit (ignored)
    dw 0                        ; Base (ignored)
    db 0                        ; Base (ignored)
    db 0x9A                     ; Access byte
    db 0x20                     ; Flags (L=1 for long mode)
    db 0                        ; Base (ignored)
DATA_SEG_64 equ $ - gdt_64
    dw 0                        ; Limit (ignored)
    dw 0                        ; Base (ignored)
    db 0                        ; Base (ignored)
    db 0x92                     ; Access byte
    db 0x00                     ; Flags
    db 0                        ; Base (ignored)

gdt64_descriptor:
    dw $ - gdt_64 - 1           ; Size
    dd gdt_64                   ; Address

%include "boot/diskLoad.asm"

db "E"