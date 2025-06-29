# Makefile for a 64-bit OS on a native x86_64 host
# This version has been checked for correct TAB formatting.

CC = gcc
LD = ld
AS = nasm

CFLAGS = -ffreestanding -nostdlib -g -m64 -fno-pic -mcmodel=kernel -mno-red-zone -Wall -Wextra
LDFLAGS = -T kernel/linker.ld -nostdlib

K_OBJ = kernel/kernel.o
KERNEL_ELF = kernel/kernel.elf
OS_IMG = aronaos.img

# Default target
all: $(OS_IMG)

# Rule to build the final OS image
$(OS_IMG): boot/boot.bin $(KERNEL_ELF)
	dd if=/dev/zero of=$(OS_IMG) bs=512 count=2880
	dd if=boot/boot.bin of=$(OS_IMG) conv=notrunc
	dd if=$(KERNEL_ELF) of=$(OS_IMG) bs=512 seek=1 conv=notrunc

# Rule to link the kernel
$(KERNEL_ELF): $(K_OBJ)
	$(LD) $(LDFLAGS) -o $(KERNEL_ELF) $(K_OBJ)

# Rule to compile the kernel
$(K_OBJ): kernel/kernel.c
	$(CC) $(CFLAGS) -c kernel/kernel.c -o $(K_OBJ)

# Rule to build the bootloader
boot/boot.bin: boot/boot.asm
	$(AS) -f bin boot/boot.asm -o boot/boot.bin

# Rule to clean up build files
clean:
	rm -f boot/*.bin kernel/*.o $(KERNEL_ELF) $(OS_IMG)

# Rule to run with QEMU
run: $(OS_IMG)
	qemu-system-x86_64 -fda $(OS_IMG)

.PHONY: all clean run