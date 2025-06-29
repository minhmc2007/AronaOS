[ORG 0x7C00]
[BITS 16]

start:
    ; --- Basic Setup ---
    mov bp, 0x9000
    mov sp, bp
    mov si, loading_msg
    call print_string

    ; --- 1. Load Kernel to a safe temporary address ---
    mov ax, 0x2000  ; Segment for 0x20000
    mov es, ax
    mov bx, 0x0000  ; Offset
    mov dh, 32      ; Load 32 sectors (16KB)
    call load_disk

    ; --- Copy Kernel from temp 0x20000 to final 0x100000 ---
    mov esi, 0x20000
    mov edi, 0x100000
    mov ecx, 32 * 512 / 4 ; 16KB in dwords
    cld
    rep movsd

    ; --- 2. Set Up Paging ---
    call setup_paging

    ; --- 3. Enable Long Mode bits ---
    mov eax, cr4
    or eax, 1 << 5      ; Enable PAE
    mov cr4, eax

    mov ecx, 0xC0000080 ; EFER MSR
    rdmsr
    or eax, 1 << 8      ; Enable LME (Long Mode Enable)
    wrmsr

    ; --- 4. Load GDT and Enable Paging ---
    lgdt [gdt64_ptr]
    mov eax, cr0
    or eax, 1 << 31 | 1 ; Enable Paging (PG) and Protection (PE)
    mov cr0, eax

    ; --- 5. Far Jump to 64-bit kernel entry (at 0x100000) ---
    jmp 0x08:long_mode_start

; --- Helper routines ---

print_string:
    mov ah, 0x0e
.print_str_loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_str_loop
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
    ; Zero out 3 pages of memory for page tables (PML4, PDPT, PD)
    mov edi, 0x1000
    mov ecx, (4096 * 3) / 4
    xor eax, eax
    rep stosd

    ; Point CR3 to the PML4 table at 0x1000
    mov edi, 0x1000
    mov cr3, edi

    ; PML4[0] -> PDPT at 0x2000
    mov dword [edi], 0x2003

    ; PDPT[0] -> PD at 0x3000
    mov edi, 0x2000
    mov dword [edi], 0x3003

    ; PD[0] -> 2MB page starting at address 0
    mov edi, 0x3000
    mov dword [edi], 0x00083 ; Present, R/W, 2MB Page Size
    ret

; --- Minimal 64-bit GDT ---
gdt64:
    dq 0 ; Null Descriptor
gdt64_code: equ $ - gdt64 ; Offset 0x08
    dw 0       ; limit 15:0
    dw 0       ; base 15:0
    db 0       ; base 23:16
    db 0x9A    ; access byte (Present, Ring 0, Code, Exec/Read)
    db 0x20    ; flags (L-bit for 64-bit code)
    db 0       ; base 31:24
gdt64_data: equ $ - gdt64 ; Offset 0x10
    dw 0       ; limit 15:0
    dw 0       ; base 15:0
    db 0       ; base 23:16
    db 0x92    ; access byte (Present, Ring 0, Data, Read/Write)
    db 0x00    ; flags
    db 0       ; base 31:24
gdt64_ptr:
    dw $ - gdt64 - 1 ; GDT size
    dq gdt64         ; GDT base address

[BITS 64]
long_mode_start:
    ; Set up data segments
    mov ax, gdt64_data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov rsp, 0x90000 ; Set up stack pointer
    ; Far jump to kernel
    jmp 0x100000

[BITS 16]
loading_msg db 'Loading AronaOS 64-bit...', 13, 10, 0
err_msg db 'Disk read error!', 0

times 510 - ($ - $$) db 0
dw 0xAA55