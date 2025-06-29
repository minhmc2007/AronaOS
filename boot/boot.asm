[ORG 0x7C00]
[BITS 16]

start:
    ; --- Interrupt-Safe Stack Setup ---
    cli
    mov ax, 0x8000
    mov ss, ax
    mov sp, 0xFFFF
    sti

    mov [boot_drive], dl

    mov si, loading_msg
    call print_string

    ; --- 1. Load Kernel ---
    mov ax, 0x2000
    mov es, ax
    mov bx, 0
    call load_disk
    mov si, success_msg
    call print_string

    ; --- Copy Kernel to its final location ---
    mov esi, 0x20000
    mov edi, 0x100000
    mov ecx, 32 * 512 / 2
    cld
    rep movsw

    ; --- 2. Set Up Paging ---
    call setup_paging

    ; --- 3. Enable PAE and LME ---
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; --- 4. Maximum Compatibility Transition to Long Mode ---
    lgdt [gdt64_ptr]
    mov eax, cr0
    or eax, 1 << 0
    mov cr0, eax
    jmp gdt32_code:protected_mode_stub

[BITS 32]
protected_mode_stub:
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    jmp gdt64_code:long_mode_start

[BITS 16]
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

load_disk:
    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    ret

disk_error:
    mov si, error_msg
    call print_string
    cli
    hlt

setup_paging:
    mov edi, 0x1000
    mov ecx, 4096*3
    xor eax, eax
    rep stosd
    mov edi, 0x1000
    mov cr3, edi
    mov dword [edi], 0x2003
    mov edi, 0x2000
    mov dword [edi], 0x3003
    mov edi, 0x3000
    mov dword [edi], 0x00083
    ret

; --- GDT with both 32-bit and 64-bit descriptors ---
gdt64:
    dq 0 ; Null Descriptor
gdt32_code: equ $ - gdt64
    dw 0xFFFF  ; Limit
    dw 0       ; Base
    db 0       ; Base
    db 0x9A    ; Access
    db 0xCF    ; Granularity
    db 0       ; Base
gdt64_code: equ $ - gdt64
    dw 0       ; Limit (ignored)
    dw 0       ; Base (ignored)
    db 0       ; Base (ignored)
    db 0x9A    ; Access
    db 0x20    ; Granularity (L-bit for 64-bit)
    db 0       ; Base (ignored)
gdt64_data: equ $ - gdt64
    dw 0       ; Limit (ignored)
    dw 0       ; Base (ignored)
    db 0       ; Base (ignored)
    db 0x92    ; Access
    db 0x00    ; Granularity
    db 0       ; Base (ignored)
gdt64_ptr:
    ; CORRECTED SYNTAX: Each definition on its own line
    dw $ - gdt64 - 1 ; GDT size
    dq gdt64         ; GDT base address

[BITS 64]
long_mode_start:
    mov ax, gdt64_data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000
    jmp 0x100000

[BITS 16]
boot_drive  db 0
loading_msg db 'AronaOS Bootloader (Max-Compat)...', 13, 10, 0
success_msg db 'Kernel loaded. Switching to Long Mode...', 13, 10, 0
error_msg   db 'FATAL: Disk Read Error!', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
