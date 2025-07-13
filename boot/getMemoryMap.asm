[bits 16]
MEMORY_MAP_BUFFER_ADDRESS equ 0xdc00 
getUpperMemoryMap:
    pusha
    mov ebx, 0     ; table counter 
    
    mov ax, 0
    mov es, ax
    
    mov di, MEMORY_MAP_BUFFER_ADDRESS
    mov ax, 0xe820 ; func code

    mov ecx, 20
    mov edx, 0x534D4150           ; 'SMAP' magic, edx doesn't change
    
.loop:
    mov ax, 0xe820 ; func code

    mov ecx, 20

    clc

    int 15h

    jc .end
    cmp eax, edx
    jne .getMemoryMapError

    add di, 20 ; increase di pointer

    cmp ebx, 0
    jne .saveEBX
.end:
    popa
    ret
.saveEBX:
    mov [memoryMapLength], ebx
    jmp .loop

.getMemoryMapError:
    mov si, getMemoryMapErrorMsg
    call print_string
    jmp $
    
getMemoryMapErrorMsg db "BIOS is broken!", 13, 10, 0


UMSBMagic: db "TUMP" ; leave this for another stage could be able to find the table
memoryMapLength: dd 0
memoryMapPointer: dq MEMORY_MAP_BUFFER_ADDRESS
