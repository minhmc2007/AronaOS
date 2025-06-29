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
    mov dh, 32      ; Load 32 sectors
    call load_disk

    ; --- Copy Kernel from temp 0x20000 to final 0x100000 ---
    mov si, 0x20000
    mov edi, 0x100000
    mov cx, 32 * 512 / 2
    cld
    rep movsw
    mov al, '1'
    call print_char

    ; --- 2. Set Up Paging ---
    call setup_paging
    mov al, '2'
    call print_char

    ; --- 3. Enable Long Mode bits ---
    mov eax, cr4
    or eax, 1 << 5  ; Enable PAE
    mov cr4, eax
    mov ecx, 0xC0000080 ; EFER MSR
    rdmsr
    or eax, 1 << 8  ; Enable LME (Long Mode Enable)
    wrmsr
    mov al, '3'
    call print_char

    ; --- 4. Critical Final Steps with Granular Debugging ---
    lgdt [gdt64_ptr]
    mov al, 'L' ; 'L' for LGDT successful
    call print_char

    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31 | 1 << 0
    mov cr0, eax

    jmp gdt64_code:long_mode_start ; This is the jump that likely fails

; Should never be reached. If 'J' prints, the jmp instruction itself is bad.
; But the fault usually happens *inside* the jump.
;    mov al, 'J'
;    call print_char
;    hlt

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
    mov ch, 0, cl, 2, dh, 0
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

; --- A simplified, more robust GDT for 64-bit mode ---
gdt64:
    ; Null Descriptor
    dq 0
gdt64_code: equ $ - gdt64 ; Offset 0x08
    ; 64-bit Code Segment
    dw 0       ; limit 15:0
    dw 0       ; base 15:0
    db 0       ; base 23:16
    db 0x9A    ; access byte (Present, Ring 0, Code, Exec/Read)
    db 0x20    ; flags (L-bit for 64-bit code)
    db 0       ; base 31:24
gdt64_data: equ $ - gdt64 ; Offset 0x10
    ; 64-bit Data Segment
    dw 0       ; limit 15:0
    dw 0       ; base 15:0
    db 0       ; base 23:16
    db 0x92    ; access byte (Present, Ring 0, Data, Read/Write)
    db 0x00    ; flags (L-bit must be 0 for data)
    db 0       ; base 31:24
gdt64_ptr:
    dw $ - gdt64 - 1 ; GDT size
    dq gdt64         ; GDT base address

[BITS 64]
long_mode_start:
    ; We are now in 64-bit mode. Selectors are offsets from GDT base.
    mov ax, gdt64_data ; Selector for our data segment (0x10)
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov rsp, 0x90000 ; Set up stack pointer
    jmp 0x100000     ; Jump to kernel

[BITS 16]
loading_msg db 'Loading AronaOS 64-bit... ', 0
err_msg db 'Disk read error!', 0

times 510 - ($ - $$) db 0
dw 0xAA55
