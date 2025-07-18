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
