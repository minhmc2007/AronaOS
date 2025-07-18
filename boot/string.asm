;    Copyright (C) 2025  QUOC TRUNG NGUYEN
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

;ebx = dest, ecx = src, edx= length
fmemcpy:
    pushad

    mov eax, 0
    .loop:
        mov edi, [ecx]
        mov [ebx], edi
        add ecx, 4
        add ebx, 4
        add eax, 4
        
        cmp edx, eax
        jg .loop
    
    popad
    ret