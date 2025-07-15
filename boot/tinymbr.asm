org 0x7c5a ; avoid 90 bytes of fat32 BPB 
bits 16
start:
    pusha ; save current state
.diskLoad:
    mov ax, 0
    mov es, ax

    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 3
    mov dh, 0
    mov bx, 0x7e00

    int 0x13

    jc .error

    cmp al, 1
    jne .error

    jmp .intoRealMBR

.error:
    mov al, 'X'
    mov bh, 0
    mov bl, 5
    mov cx, 4

    mov ah, 0x9
    int 0x10
    hlt
    jmp $

.intoRealMBR:
    popa ; restore
    jmp 0x7e00
    
db "TINYMBR" ; this for debugging
