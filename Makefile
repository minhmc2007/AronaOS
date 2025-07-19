CC=gcc
CXX=g++
LD=ld
AS=nasm
OBJCOPY=objcopy

CFLAGS = -O0 -fno-stack-protector -m32 -ffreestanding -nostdlib -fno-builtin -fno-pic -I ./
LDFLAGS = -T boot/stage2/linker.ld -nostdlib -melf_i386
asmPreKernelFlags = -f elf64

preKernelFolder=boot/stage2
bootEntryFolder=boot
KernelFolder=kernel

preKernelOutput=$(preKernelFolder)/preKernel.bin
preKernelELF=$(preKernelFolder)/stage2
bootEntryOutput=$(bootEntryFolder)/boot.bin

preKernelSRC=
preKernelOBJ=

bootEntrySRC=$(shell find boot -type f -name "*.asm")
IMG_FOLDERS=$(shell find ./img/ -type d -maxdepth 1)
IMG_FILES=$(shell find ./img/ -type f -maxdepth 1)

bootstrap=img/boot/BS
imgOutput=aronaos.img

checkBuildStatus: $(imgOutput)
	@echo "Okay"

run: $(imgOutput)
	@echo "Running [$<]"
	@echo "" > log.txt
	@qemu-system-x86_64 $< -no-reboot -m 1G -D log.txt -d int

$(imgOutput): $(bootEntryOutput) $(bootstrap) buildTools/buildTools boot/tinymbr.bin
	@rm -f $@
	@dd if=/dev/zero of=$(imgOutput) bs=512 count=10000
	@mkfs.fat -F 32 $@
	@dd if=$(bootEntryOutput) of=$(imgOutput) bs=512 seek=2 conv=notrunc
	@echo "Created disk img!"
	@echo "Install tinymbr"
	@buildTools/buildTools install-bios $(imgOutput) boot/tinymbr.bin
	@mcopy -i $(imgOutput) ./img/boot ::
	@rm ./img/boot/BS

$(bootstrap):
	@$(MAKE) -C bootstrap

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
	@rm $(bootstrap) $(shell find ./ -type f -name "*.o") $(preKernelELF) $(preKernelOutput) $(imgOutput) $(bootEntryOutput)
	@echo Okay
