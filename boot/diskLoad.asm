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

DISK_READ_OUTPUT_ADDRESS equ 0xa000

db "DLD" ; "DLD" table signature
DLD:
.functionPointer:
    dd diskLoadData

.bootDrive:
    db 0

.diskAddressPacket:
.size:
    db 16 ; size
.reserved:
    db 0
.sector:
    dw 1 ; read 1 sector per call
.offset:
    dw DISK_READ_OUTPUT_ADDRESS 
.segment:
    dw 0 ; segment
.LBA:
    dq 0
.outputAddress:
    dd DISK_READ_OUTPUT_ADDRESS
.result:
    db 0

[bits 16]
diskLoadData:
    mov ax, 0
    mov ds, ax

    mov si, DLD.diskAddressPacket
    mov ah, 0x42
    mov dl, 0x80; boot_drive
    int 0x13

    jc .error

    mov byte [DLD.result], 1
    ret

.error:
    mov si, E
    call print_string
    mov byte [DLD.result], 0
    jmp $

E: db "Read disk failed!", 13, 10, 0