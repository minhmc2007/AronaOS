DISK_READ_OUTPUT_ADDRESS equ 0xd000

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
.segment
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