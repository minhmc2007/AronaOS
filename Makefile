CC=gcc
CXX=g++
LD=ld
AS=nasm
OBJCOPY=objcopy

CFLAGS = -ffreestanding -nostdlib -fno-builtin -fno-pic -mcmodel=kernel -mno-red-zone
LDFLAGS = -T preKernel/linker.ld -nostdlib
asmPreKernelFlags = -f elf64

preKernelFolder=preKernel
bootEntryFolder=boot
KernelFolder=kernel

preKernelOutput=$(preKernelFolder)/preKernel.bin
preKernelELF=$(preKernelFolder)/preKernel.elf
bootEntryOutput=$(bootEntryFolder)/boot.bin

preKernelSRC=$(shell find $(preKernelFolder) -type f -name "*.c") $(shell find $(preKernelFolder) -type f -name "*.asm") $(shell find $(preKernelFolder) -type f -name "*.cpp")
preKernelOBJ=$(patsubst %, %.preKernel.o, $(preKernelSRC))

bootEntrySRC=$(bootEntryFolder)/boot.asm

imgOutput=aronaos.img

checkBuildStatus: $(imgOutput)
	@echo "Okay"

run: $(imgOutput)
	@echo "Running [$<]"
	@qemu-system-x86_64 $< -no-reboot -m 1G

$(imgOutput): $(bootEntryOutput) $(preKernelOutput)
	@dd if=/dev/zero of=$(imgOutput) bs=512 count=2880
	@dd if=$(bootEntryOutput) of=$(imgOutput) conv=notrunc

	@dd if=$(preKernelOutput) of=$(imgOutput) bs=512 seek=2 conv=notrunc
	@echo "Created disk img!"

$(bootEntryOutput): $(bootEntrySRC)
	@echo "[AS] $< -> $@"
	@$(AS) -f bin $< -o $@

$(preKernelOutput):  $(preKernelELF)
	@echo "Convert $< to $@"
	@$(OBJCOPY) -O binary $< $@
	
$(preKernelELF): $(preKernelOBJ) preKernel/linker.ld
	@echo "Linking $@..."
	@$(LD) $< -o $@ $(LDFLAGS)

%.c.preKernel.o: %.c
	@echo "[CC] $< -> $@"
	@$(CC) -c $< -o $@ $(CFLAGS) 

%.cpp.preKernel.o: %.cpp
	@echo "[CXX] $< -> $@"
	@$(CXX) -c $< -o $@ $(CFLAGS) 

%.asm.preKernel.o: %.asm
	@echo "[AS] $< -> $@"
	@$(AS) $(asmPreKernelFlags) $< -o $@ 

clean:
	@rm $(shell find ./ -type f -name "*.o") $(preKernelELF) $(preKernelOutput) $(imgOutput)
	@echo Okay
