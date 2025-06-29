[ORG 0x7C00]
[BITS 16]

start:
    mov bp, 0x9000
    mov sp, bp
    mov si, loading_msg
    call print_string

    ; --- 1. Load Kernel ---
    ; Set up a safe temporary load address at 0x20000 (128KB)
    ; es:bx = 0x2000:0x0000 -> physical address 0x20000
    mov ax, 0x2000
    mov es, ax
    mov bx, 0x0000

    mov dh, 32  ; Load 32 sectors (16KB)
    call load_disk

    ; Now that it's loaded, copy it from the temporary location (0x20000)
    ; to its final high-memory location (0x100000).
    mov si, 0x20000
    mov edi, 0x100000
    mov cx, 32 * 512 / 2 ; Word count to copy
    cld
    rep movsw

    mov al, '1' ; Should now print successfully
    call print_char

    ; --- 2. Set Up Paging ---
    call setup_paging
    mov al, '2'
    call print_char

    ; --- 3. Enter Long Mode ---
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    mov al, '3'
    call print_char

    ; --- 4. Enable Paging & Jump to 64-bit ---
    mov eax, cr0
    or eax, 1 << 31 | 1 << 0
    mov cr0, eax
    lgdt [gdt64_ptr]
    jmp gdt64_code:long_mode_start

print_char:
    mov ah, 0x0e
    int 0x10
    ret

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
    mov al, dh
    mov ch, 0
    mov cl, 2
    mov dh, 0
    int 0x13
    jc disk_error
    ret

disk_error:
    mov si, err_msg
    call print_string
    cli
    hlt

setup_paging:
    mov edi, 0x1000
    mov ecx, 4096 * 3
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

[BITS 64]
long_mode_start:
    mov ax, 0x10 ; Selector for our data segment
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000
    jmp 0x100000 ; Jump to the pure binary code

[BITS 16]
loading_msg db 'Loading AronaOS 64-bit... ', 0
err_msg db 'Disk read error!', 0
gdt64:
    dq 0 ; Null
gdt64_code:
    dw 0xFFFF, 0
    db 0, 0b10011010, 0b10101111, 0 ; 64-bit Code
gdt64_data:
    dw 0xFFFF, 0
    db 0, 0b10010010, 0b11001111, 0 ; 64-bit Data
gdt64_ptr:
    dw $ - gdt64 - 1
    dq gdt64

times 510 - ($ - $$) db 0
dw 0xAA55
