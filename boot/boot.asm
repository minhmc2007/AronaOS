[org 0x7C00]
[bits 16]
STAGE2_ADDRESS equ 0x7e00
PMM_STACK_ADDRESS equ 0x1F0000

start:
    mov dword [RM_STACK_ADDRESS], esp ; save realmode stack 
    ; clear screen by resetting video mode
    mov ah, 0xf
    int 0x10
    mov ah, 0x00
    int 0x10

    ; Dont need to set up stack here, BIOS will do it for us
    ; cli
    ; ; Set up stack in a safe location
    ; mov ax, 0x9000
    ; mov ss, ax
    ; mov sp, 0xFFFF
    ; sti
    ; mov si, stack_set_msg
    ; call print_string

    ; Save boot drive
    mov [boot_drive], dl
    ; mov si, boot_drive_saved_msg
    ; call print_string

    ; Initialize VGA offset !!!! dont need this, using this may cause some problems 
    ; mov ax, 0x9020
    ; mov fs, ax
    ; mov word [fs:0x0], 0
    ; mov si, vga_init_msg
    ; call print_string

    ; Print loading message
    ; Load kernel to 0x8000:0 (physical 0x80000)
    ; load at 0x7e00
    mov ax, 0
    mov es, ax
    mov bx, STAGE2_ADDRESS

    ; Load stage2 from disk
    mov ah, 0x02
    mov al, 10        ; load 10 sector
    mov ch, 0         ; Cylinder 0
    mov cl, 2         ; Sector 2 (first sector after bootloader)
    mov dh, 0         ; Head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    cmp al, 10         ; Check if we read 10 sectors
    jne disk_error

    call getUpperMemoryMap
    ; Enter 32-bit protected mode
    call enter_protected_mode

RM_STACK_ADDRESS:
    dd 0

print_string:
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
    pop si
    pop ax
    ret

pm2rmCTest:
    mov si, ttt
    call print_string
    ret
ttt db "OKAY??", 13, 10, 0

db "DRET"
dd pm2rmCTest
disk_error:
    mov si, error_msg
    call print_string
    hlt
    jmp $

boot_drive      db 0
error_msg       db "DRE", 13, 10, 0

%include "boot/pm2rm.asm"


savedCr0: dd 0
db "E"
; Boot signature
times 510 - ($ - $$) db 0
dw 0xAA55

stage2Begin:

%include "boot/getMemoryMap.asm"

enter_protected_mode:
    cli
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enable protected mode
    mov eax, cr0
    mov [savedCr0], eax
    or eax, 1
    mov cr0, eax
    
    ; Far jump to flush prefetch queue and enter protected mode
    jmp CODE_SEG_32:protected_mode_start

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
    mov esp, PMM_STACK_ADDRESS

    jmp 0x8000

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

print_string_vga_32:
    push eax
    push edi
    mov edi, [0x90200]        ; Load VGA offset
.loop:
    lodsb
    cmp al, 0
    je .done
    mov byte [0xB8000 + edi], al
    mov byte [0xB8000 + edi + 1], 0x07 ; White on black
    add edi, 2
    jmp .loop
.done:
    mov [0x90200], edi        ; Save VGA offset
    pop edi
    pop eax
    ret

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
    mov rsp, 0x1F0000 ; set as LONGMODE STACK

    mov esi, TEST
    call print_

    ; Jump to kernel
    jmp 0x8000

; print_string_vga_64:
;     push rax
;     push rdi
;     mov edi, [0x90200]        ; Load VGA offset (32-bit for simplicity)
; .loop:
;     lodsb
;     cmp al, 0
;     je .done
;     mov byte [0xB8000 + rdi], al
;     mov byte [0xB8000 + rdi + 1], 0x07
;     add edi, 2
;     jmp .loop
; .done:
;     mov [0x90200], edi        ; Save VGA offset
;     pop rdi
;     pop rax
;     ret
termLine: dd 0xb8000
TEST: db "OK NOW!", 0
print_:
    mov ebx, [termLine]
    .loop:
        mov ax, 0x0f00
        mov al, [esi]
        cmp al, 0
        je .end

        mov [ebx], ax

        add ebx, 2
        inc esi
        jmp .loop
    .end:
        add dword [termLine], 80*2
        ret

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

; Data section

; vga_init_msg    db 'VGA offset initialized', 13, 10, 0
; loading_msg     db 'Loading AronaOS bootloader ...', 13, 10, 0
; kernel_loaded_msg db 'Kernel loaded successfully', 13, 10, 0
; entering_pm_msg db 'Entering protected mode', 13, 10, 0
; long_mode_transition_msg db 'Transitioning to long mode', 0
; long_mode_msg   db 'In long mode', 0


abc db "AronaOS Bootloader", 0

times 512 - ($ - stage2Begin) db 0