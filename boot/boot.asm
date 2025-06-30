[ORG 0x7C00]
[BITS 16]

start:
    cli
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xFFFF
    sti

    mov [boot_drive], dl

    mov si, loading_msg
    call print_string

    ; Set up destination address for kernel loading
    mov ax, 0x1000
    mov es, ax
    mov bx, 0

    ; Load kernel from disk
    mov ah, 0x02
    mov al, 32 ; Load 32 sectors
    mov ch, 0  ; Cylinder 0
    mov cl, 2  ; Sector 2
    mov dh, 0  ; Head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    mov si, kernel_msg
    call print_string

    ; --- Switch to 64-bit Long Mode ---
    ; 1. Set up Page Tables
    call setup_paging

    ; 2. Load GDT
    lgdt [gdt_ptr]

    ; 3. Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 4. Enable Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 5. Enable Paging
    mov eax, cr0
    or eax, 0x80000001 ; Set PG (bit 31) and PE (bit 0)
    mov cr0, eax

    ; 6. Jump to Long Mode
    jmp CODE_SEG:long_mode_start

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

setup_paging:
    ; Zero out page tables (PML4, PDP, and one PD)
    mov edi, 0x1000
    mov ecx, 4096 * 3
    xor eax, eax
    rep stosd

    ; PML4 at 0x1000 -> points to PDP at 0x2000
    mov edi, 0x1000
    mov dword [edi], 0x2003 ; Present, R/W

    ; PDP at 0x2000 -> points to PD at 0x3000
    mov edi, 0x2000
    mov dword [edi], 0x3003 ; Present, R/W

    ; Page Directory at 0x3000
    ; This will contain 512 entries, each mapping a 2MB page, for a total of 1GB.
    mov edi, 0x3000
    mov ecx, 512
    mov eax, 0x00000083 ; Flags: Present, R/W, Page Size (2MB)
.map_loop:
    mov dword [edi], eax
    mov dword [edi+4], 0 ; Upper 32 bits of address are 0
    add edi, 8           ; Advance to next 64-bit entry
    add eax, 0x200000    ; Next 2MB physical address
    loop .map_loop

    ; Load the address of the PML4 into CR3
    mov eax, 0x1000
    mov cr3, eax
    ret

gdt:
    dq 0 ; Null Descriptor
CODE_SEG equ $ - gdt
    dw 0xFFFF
    dw 0
    db 0
    db 0x9A
    db 0x20
    db 0
DATA_SEG equ $ - gdt
    dw 0xFFFF
    dw 0
    db 0
    db 0x92
    db 0xCF
    db 0
gdt_ptr:
    dw $ - gdt - 1
    dq gdt

[BITS 64]
long_mode_start:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rsp, 0x90000
    jmp 0x100000

[BITS 16]
boot_drive  db 0
loading_msg db 'Loading AronaOS bootloader ...', 13, 10, 0
kernel_msg  db 'Loading AronaOS kernel v0.1 ...', 13, 10, 0
error_msg   db 'FATAL: Disk Read Error!', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
