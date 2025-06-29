# Makefile for a 64-bit OS on a native x86_64 host
# This version creates a flat binary kernel and writes it to the image.

CC = gcc
LD = ld
AS = nasm
OBJCOPY = objcopy

CFLAGS = -ffreestanding -nostdlib -g -m64 -fno-pic -mcmodel=kernel -mno-red-zone -Wall -Wextra
LDFLAGS = -T kernel/linker.ld -nostdlib

K_SRC = kernel/kernel.c
K_OBJ = kernel/kernel.o
KERNEL_ELF = kernel/kernel.elf
KERNEL_BIN = kernel/kernel.bin  # The flat binary target
OS_IMG = aronaos.img

# Default target
all: $(OS_IMG)

# Rule to build the final OS image
$(OS_IMG): boot/boot.bin $(KERNEL_BIN)
	dd if=/dev/zero of=$(OS_IMG) bs=512 count=2880
	dd if=boot/boot.bin of=$(OS_IMG) conv=notrunc
	# Write the flat binary kernel, NOT the ELF file
	dd if=$(KERNEL_BIN) of=$(OS_IMG) bs=512 seek=1 conv=notrunc

# Rule to create the flat binary from the ELF file
$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $(KERNEL_ELF) $(KERNEL_BIN)

# Rule to link the kernel ELF file
$(KERNEL_ELF): $(K_OBJ)
	$(LD) $(LDFLAGS) -o $(KERNEL_ELF) $(K_OBJ)

# Rule to compile the kernel
$(K_OBJ): $(K_SRC)
	$(CC) $(CFLAGS) -c $(K_SRC) -o $(K_OBJ)

# Rule to build the bootloader
boot/boot.bin: boot/boot.asm
	$(AS) -f bin boot/boot.asm -o boot/boot.bin

# Rule to clean up build files
clean:
	rm -f boot/*.bin kernel/*.o $(KERNEL_ELF) $(KERNEL_BIN) $(OS_IMG)

# Rule to run with QEMU
run: $(OS_IMG)
	qemu-system-x86_64 -fda $(OS_IMG)

.PHONY: all clean run
