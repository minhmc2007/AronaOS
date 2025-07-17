bits 32
println:
    pushad
    mov ecx, dword [.dest]
    .loop:
        mov al, byte [esi]
        cmp al, 0
        je .end

        mov ah, 0xf5
        mov word [ecx], ax 
        inc esi
        add ecx, 2
        jmp .loop
    .end:
    add dword [.dest], 80 * 2
    popad
    ret
.dest:
    dd 0xb8000