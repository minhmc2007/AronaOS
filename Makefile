CC=gcc
CXX=g++
LD=ld
AS=nasm
OBJCOPY=objcopy

CFLAGS = -fno-stack-protector -m32 -ffreestanding -nostdlib -fno-builtin -fno-pic -I ./
LDFLAGS = -T boot/stage2/linker.ld -nostdlib -melf_i386
asmPreKernelFlags = -f elf64

preKernelFolder=boot/stage2
bootEntryFolder=boot
KernelFolder=kernel

preKernelOutput=$(preKernelFolder)/preKernel.bin
preKernelELF=$(preKernelFolder)/stage2
bootEntryOutput=$(bootEntryFolder)/boot.bin

preKernelSRC=$(shell find $(preKernelFolder) -type f -name "*.c") $(shell find $(preKernelFolder) -type f -name "*.asm") $(shell find $(preKernelFolder) -type f -name "*.cpp")
preKernelOBJ=$(patsubst %, %.preKernel.o, $(preKernelSRC))

bootEntrySRC=$(shell find boot -type f -name "*.asm")

imgOutput=aronaos.img

checkBuildStatus: $(imgOutput)
	@echo "Okay"

run: $(imgOutput)
	@echo "Running [$<]"
	@qemu-system-x86_64 $< -no-reboot -m 1G

$(imgOutput): $(bootEntryOutput) $(preKernelOutput) buildTools/buildTools boot/tinymbr.bin
	@dd if=/dev/zero of=$(imgOutput) bs=512 count=2880
	@mkfs.fat -F 32 $@
	@dd if=$(bootEntryOutput) of=$(imgOutput) bs=512 seek=2 conv=notrunc
	@dd if=$(preKernelOutput) of=$(imgOutput) bs=512 seek=5 conv=notrunc
	@echo "Created disk img!"
	@echo "Install tinymbr"
	@buildTools/buildTools $(imgOutput) boot/tinymbr.bin

boot/tinymbr.bin: boot/tinymbr.asm
	@echo "[AS] boot/tinymbr.asm -> $@"
	@$(AS) -f bin boot/tinymbr.asm -o $@

$(bootEntryOutput): $(bootEntrySRC)
	@echo "[AS] boot/boot.asm -> $@"
	@$(AS) -f bin boot/boot.asm -o $@

$(preKernelOutput):  $(preKernelELF)
	@echo "Convert $< to $@"
	@$(OBJCOPY) -O binary $< $@
	
$(preKernelELF): $(preKernelOBJ) boot/stage2/linker.ld
	@echo "Linking $@..."
	@$(LD) -o $@ $(LDFLAGS) $(preKernelOBJ)

%.c.preKernel.o: %.c
	@echo "[CC] $< -> $@"
	@$(CC) -c $< -o $@ $(CFLAGS) 

%.cpp.preKernel.o: %.cpp
	@echo "[CXX] $< -> $@"
	@$(CXX) -c $< -o $@ $(CFLAGS) 

%.asm.preKernel.o: %.asm
	@echo "[AS] $< -> $@"
	@$(AS) $(asmPreKernelFlags) $< -o $@ 

buildTools/buildTools: buildTools/buildTools.c
	@echo "[CC] $< -> $@"
	@$(CC) $< -o $@

clean:
	@rm $(shell find ./ -type f -name "*.o") $(preKernelELF) $(preKernelOutput) $(imgOutput) $(bootEntryOutput)
	@echo Okay
