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

[bits 16]
MEMORY_MAP_BUFFER_ADDRESS equ 0xe000 
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
    jmp $
    


UMSBMagic: db "TUMP" ; leave this for another stage could be able to find the table
memoryMapLength: dd 0
memoryMapPointer: dq MEMORY_MAP_BUFFER_ADDRESS
