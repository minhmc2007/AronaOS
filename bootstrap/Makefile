CXX=g++
LD=ld
ASM=nasm

CXX_FLAGS= -I ./ \
    -Wall \
    -Wextra \
    -ffreestanding \
    -fno-stack-protector \
    -fno-stack-check \
    -fno-lto \
    -fno-PIC \
    -m64 \
    -march=x86-64 \
    -mno-80387 \
    -mno-mmx \
    -mno-sse \
    -mno-sse2 \
    -mno-red-zone \
    -mcmodel=kernel
LD_FLAGS=-m elf_x86_64 -nostdlib -static -T linker.ld

CXXSRC=$(shell find ./ -type f -name "*.cpp")
CXXOBJ=$(patsubst %, %.o, $(CXXSRC))
ASMSRC=$(shell find ./ -type f -name "*.asm")
ASMOBJ=$(patsubst %.asm, %.asm.o, $(ASMSRC))
OUTPUT=../img/boot/BS

$(OUTPUT): $(CXXOBJ) $(ASMOBJ)
	@echo "Linking ..."
	@$(LD) $(LD_FLAGS) $(CXXOBJ) $(ASMOBJ) -o bootstrap
	@objcopy -O binary bootstrap $@

%.cpp.o: %.cpp
	@echo "[CXX] $<..."
	@$(CXX) $(CXX_FLAGS) -c $< -o $@

%.asm.o:%.asm
	@echo "[ASM] $<..."
	@$(ASM) -felf64 $< -o $@

clean:
	@rm $(shell find ./ -type f -name "*.o")
