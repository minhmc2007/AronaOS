CXX=g++
LD=ld

CXX_FLAGS= -Wall \
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
CXXOBJ=$(patsubst %.cpp, %.o, $(CXXSRC))

OUTPUT=../img/boot/BS

$(OUTPUT): $(CXXOBJ)
	@echo "Linking ..."
	@$(LD) $(LD_FLAGS) $(CXXOBJ) -o bootstrap
	@objcopy -O binary bootstrap $@

%.o: %.cpp
	@echo "[CXX] $<..."
	@$(CXX) $(CXX_FLAGS) -c $< -o $@