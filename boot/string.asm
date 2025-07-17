bits 32
;use eax, ebx as arguments
astrcmp:
    pushad

    .loop:
        mov cl, byte[eax]
        mov ch, byte[ebx]
        cmp cl, ch
        je .tloop
    .end:
    mov dword [.result], 0
    popad
    ret
.tloop:
    cmp byte[eax], 0
    je .eend
    add eax, 1
    add ebx, 1
    jmp .loop
.eend:
    mov dword [.result], 1
    popad
    ret
.result:
    dd 0