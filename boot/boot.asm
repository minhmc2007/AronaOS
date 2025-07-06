[ORG 0x7C00]
[BITS 16]

start:
    cli
    ; Set up stack in a safe location
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xFFFF
    sti

    ; Save boot drive
    mov [boot_drive], dl

    ; Print loading message
    mov si, loading_msg
    call print_string

    ; Load kernel to 0x8000:0 (physical 0x80000) to avoid conflicts
    mov ax, 0x8000
    mov es, ax
    mov bx, 0

    ; Load kernel from disk
    mov ah, 0x02
    mov al, 32        ; Load 32 sectors
    mov ch, 0         ; Cylinder 0
    mov cl, 2         ; Sector 2 (first sector after bootloader)
    mov dh, 0         ; Head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov si, kernel_msg
    call print_string

    ; First enter 32-bit protected mode
    call enter_protected_mode
    
    ; This code never executes because we jump to 32-bit code
    jmp $

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

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

disk_error:
    mov si, error_msg
    call print_string
    cli
    hlt

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
    mov esp, 0x90000

    ; Now set up paging for long mode
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
    ; Clear page tables area (16KB total)
    mov edi, 0x1000
    mov ecx, 4096
    xor eax, eax
    rep stosd

    ; Set up PML4 (Page Map Level 4)
    mov edi, 0x1000
    mov dword [edi], 0x2003     ; Point to PDP, present + writable

    ; Set up PDP (Page Directory Pointer)
    mov edi, 0x2000
    mov dword [edi], 0x3003     ; Point to PD, present + writable

    ; Set up PD (Page Directory) - identity map first 1GB
    mov edi, 0x3000
    mov ecx, 512                ; 512 entries
    mov eax, 0x00000083         ; Present + writable + 2MB pages
.map_loop:
    mov dword [edi], eax        ; Lower 32 bits
    mov dword [edi + 4], 0      ; Upper 32 bits
    add edi, 8                  ; Next entry
    add eax, 0x200000           ; Next 2MB
    loop .map_loop

    ; Load CR3 with PML4 address
    mov eax, 0x1000
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
    mov rsp, 0x90000

    ; Jump to kernel (now at physical address 0x80000)
    jmp 0x80000

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
    dw 0                        ; Limit (ignored in long mode)
    dw 0                        ; Base (ignored in long mode)
    db 0                        ; Base (ignored in long mode)
    db 0x9A                     ; Access byte
    db 0x20                     ; Flags (L=1 for long mode)
    db 0                        ; Base (ignored in long mode)
DATA_SEG_64 equ $ - gdt_64
    dw 0                        ; Limit (ignored in long mode)
    dw 0                        ; Base (ignored in long mode)
    db 0                        ; Base (ignored in long mode)
    db 0x92                     ; Access byte
    db 0x00                     ; Flags
    db 0                        ; Base (ignored in long mode)

gdt64_descriptor:
    dw $ - gdt_64 - 1           ; Size
    dd gdt_64                   ; Address

; Data section
boot_drive      db 0
loading_msg     db 'Loading AronaOS bootloader ...', 13, 10, 0
kernel_msg      db 'Loading AronaOS kernel v0.1 ...', 13, 10, 0
error_msg       db 'FATAL: Disk Read Error!', 13, 10, 0

; Boot signature
times 510 - ($ - $$) db 0
dw 0xAA55
