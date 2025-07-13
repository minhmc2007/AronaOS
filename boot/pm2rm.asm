[bits 32]
pm2rm:
    cli

    lgdt [GDTR16]

    jmp (GDT16.CODE16-GDT16):.pm16
[bits 16]
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
[bits 16]  
rm:
    
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    lidt [IDTR16]
    sti

.pm2rmCaller:
    call [PM2RM_CALL_ADDRESS]

.rm2pm:
.enterProtectedMode:
    cli
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    mov [savedCr0], eax
    or eax, 1
    mov cr0, eax
    
    jmp CODE_SEG_32:.protectedModeStart

[BITS 32]
.protectedModeStart:
    mov ax, DATA_SEG_32
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    jmp [PM2RM_RETURN_ADDRESS]

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

PM2RM_CALL_ADDRESS:
    dw 0
PM2RM_RETURN_ADDRESS:
    dw 0
