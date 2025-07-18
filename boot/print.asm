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