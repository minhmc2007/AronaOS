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
pm2rmf:
    pushfd
    pushad
    cli

    lgdt [GDTR16]

    jmp (GDT16.CODE16-GDT16):.pm16
bits 16
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
bits 16  
rm:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    lidt [IDTR16]
    sti

    ; maybe we shouldn't change esp
    ; mov esp, 0
    ; mov ebp, 0
    ; mov sp, word [RM_STACK_ADDRESS]
    ; mov bp, sp

.pm2rmCaller:
    call [PM2RMF_CALL_ADDRESS]

.rm2pm:
.enterProtectedMode:
    cli
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp CODE_SEG_32:.protectedModeStart

bits 32
.protectedModeStart:
    mov ax, DATA_SEG_32
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    popad
    popfd

    ret ; return

PM2RMF_CALL_ADDRESS:
    dd 0

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
        db 0b00000000 ; flags + high limit
        db 0          ; high base
    .END: