DISK_READ_OUTPUT_ADDRESS equ 0xa000

db "DLD" ; "DLD" table signature
DLD:
.functionPointer:
    dd diskLoadData

.bootDrive:
    db 0

.diskAddressPacket:
    db 16 ; size
    db 0
    dw 4 ; read 4 sector per call
    dw DISK_READ_OUTPUT_ADDRESS 
    dw 0 ; segment
    .LBA:
        dq 0
.outputAddress:
    dd DISK_READ_OUTPUT_ADDRESS
.result:
    db 0

[bits 16]
diskLoadData:
    mov si, DLD.diskAddressPacket
    mov ah, 0x42
    mov dl, byte [DLD.bootDrive]
    int 0x13

    jc .error

    mov byte [DLD.result], 1
    ret

.error:
    mov si, E
    call print_string
    mov byte [DLD.result], 0
    ret

E: db "EEE", 13, 10, 0