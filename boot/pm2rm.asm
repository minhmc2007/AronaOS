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

    mov esp, dword [RM_STACK_ADDRESS]

.pm2rmCaller:
    call [PM2RM_CALL_ADDRESS]

.rm2pm:
.enterProtectedMode:
    cli
    lgdt [gdt_descriptor]
    
    mov eax, cr0
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

[bits 32]
pm2rmHelper:
    push ebp ; do some system v abi stuffs
    mov ebp, esp
    
.backUpRegisters:
    mov dword [.EAX], eax
    mov dword [.EBX], ebx
    mov dword [.ECX], ecx
    mov dword [.EDX], edx
    mov dword [.ESP], esp
    mov dword [.EBP], ebp
    mov dword [.EDI], edi
    mov dword [.ESI], esi

    mov eax, [ebp + 8]
    mov dword [PM2RM_CALL_ADDRESS], eax
    mov dword [PM2RM_RETURN_ADDRESS], .return
    jmp pm2rm
.return:
    mov eax, [.EAX]
    mov ebx, [.EBX]
    mov edx, [.EDX]
    mov ecx, [.ECX]
    mov esp, [.ESP]
    mov ebp, [.EBP]
    mov edi, [.EDI]
    mov esi, [.ESI]

    mov esp, ebp
    pop ebp
    ret
.EAX:
    dd 0
.EBX:
    dd 0
.ECX:
    dd 0
.EDX:
    dd 0
.ESP:
    dd 0
.EBP:
    dd 0
.EDI:
    dd 0
.ESI:
    dd 0


; address table
db "PM2RM"
dd pm2rmHelper; ADDRESS

