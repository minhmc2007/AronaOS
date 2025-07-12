/*
 * Simple x86 Emulator
 * 
 * A basic x86 CPU emulator that can load and execute 32-bit ELF binaries.
 * Implements core x86 instructions including function calls, returns, and
 * Linux system calls. Designed for educational purposes and simple program
 * execution.
 * 
 * Features:
 * - 32-bit x86 instruction emulation
 * - ELF binary loading
 * - Stack management with function calls
 * - Linux syscall emulation (exit, write)
 * - Memory bounds checking
 */

#define _GNU_SOURCE          // Enable GNU extensions for additional system calls
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <elf.h>             // ELF file format structures
#include <sys/mman.h>        // Memory mapping functions
#include <sys/syscall.h>     // System call numbers

/**
 * CPU State Structure
 * 
 * Represents the complete state of a 32-bit x86 processor.
 * Contains all general-purpose registers, stack pointer, base pointer,
 * index registers, instruction pointer, and flags register.
 */
typedef struct {
    uint32_t eax, ecx, edx, ebx;    // General-purpose registers (A, C, D, B)
    uint32_t esp, ebp, esi, edi;    // Stack pointer, base pointer, source/dest index
    uint32_t eip, eflags;           // Instruction pointer and processor flags
} CpuState;

// Memory Configuration
#define GUEST_MEM_SIZE (256 * 1024 * 1024)  // 256MB virtual memory space for guest
#define STACK_TOP (GUEST_MEM_SIZE - 4)      // Stack grows downward from top of memory

// Global pointer to guest memory space
void* g_guest_mem = NULL;

/**
 * Address Translation Function
 * 
 * Converts guest virtual addresses to host physical addresses.
 * Performs bounds checking to prevent memory corruption.
 * 
 * @param guest_addr Virtual address in guest memory space
 * @return Host pointer to corresponding memory location
 */
void* guest_to_host(uint32_t guest_addr) {
    // Validate guest address is within allocated memory bounds
    if (guest_addr >= GUEST_MEM_SIZE) {
        fprintf(stderr, "[EMU] ERROR: Memory access out of bounds: 0x%x\n", guest_addr);
        exit(1);
    }
    // Calculate host address by adding offset to base guest memory
    return (void*)((uintptr_t)g_guest_mem + guest_addr);
}

/**
 * System Call Handler
 * 
 * Emulates Linux system calls by intercepting INT 0x80 instructions.
 * Currently supports essential syscalls needed for basic program execution.
 * Uses the same calling convention as Linux x86 (EAX=syscall number).
 * 
 * @param cpu Pointer to CPU state containing syscall parameters
 */
void handle_syscall(CpuState* cpu) {
    uint32_t syscall_num = cpu->eax;  // System call number in EAX
    
    switch (syscall_num) {
        case 1: {  // sys_exit - Terminate program execution
            int exit_code = (int)cpu->ebx;  // Exit code in EBX
            printf("[EMU] Guest called sys_exit with code %d. Exiting.\n", exit_code);
            exit(exit_code);
        }
        case 4: {  // sys_write - Write data to file descriptor
            uint32_t fd = cpu->ebx;           // File descriptor in EBX
            void* buf = guest_to_host(cpu->ecx);  // Buffer address in ECX (translated)
            uint32_t count = cpu->edx;        // Byte count in EDX
            
            // Execute actual write syscall and return result in EAX
            long ret = write(fd, buf, count);
            cpu->eax = ret;
            break;
        }
        default:
            fprintf(stderr, "[EMU] ERROR: Unsupported syscall: %d\n", syscall_num);
            exit(1);
    }
}

/**
 * CPU Emulation Engine
 * 
 * Main emulation loop that fetches, decodes, and executes x86 instructions.
 * Implements a subset of x86 instruction set sufficient for basic programs.
 * 
 * Supported Instructions:
 * - MOV r32, imm32 (0xB8-0xBF): Load immediate value into register
 * - CALL rel32 (0xE8): Function call with return address pushed to stack
 * - RET (0xC3): Return from function, popping return address from stack
 * - INT 0x80 (0xCD 0x80): Software interrupt for system calls
 * 
 * @param entry_point Virtual address where program execution begins
 */
void emulate(uint32_t entry_point) {
    // Initialize CPU state with zero values
    CpuState cpu = {0};
    cpu.eip = entry_point;    // Set instruction pointer to program entry
    cpu.esp = STACK_TOP;      // Initialize stack pointer to top of stack region
    
    printf("[EMU] Starting emulation at EIP=0x%x, ESP=0x%x\n", cpu.eip, cpu.esp);

    // Register pointer array for easy access by index (matches x86 encoding)
    uint32_t* registers[] = {&cpu.eax, &cpu.ecx, &cpu.edx, &cpu.ebx, 
                            &cpu.esp, &cpu.ebp, &cpu.esi, &cpu.edi};

    // Main emulation loop - fetch, decode, execute cycle
    while (1) {
        // Fetch: Get instruction bytes from memory at current EIP
        uint8_t* inst_ptr = (uint8_t*)guest_to_host(cpu.eip);
        uint8_t opcode = *inst_ptr;  // First byte is the opcode
        
        // Decode and Execute based on opcode
        
        // MOV r32, imm32 - Move 32-bit immediate value to register
        // Opcodes 0xB8-0xBF encode the destination register in the low 3 bits
        if (opcode >= 0xB8 && opcode <= 0xBF) {
            uint32_t reg_idx = opcode - 0xB8;           // Extract register index
            *registers[reg_idx] = *(uint32_t*)(inst_ptr + 1);  // Load immediate value
            cpu.eip += 5;  // Advance EIP by instruction length (1 byte opcode + 4 byte immediate)
        }
        
        // CALL rel32 - Call function with relative offset
        else if (opcode == 0xE8) {
            int32_t offset = *(int32_t*)(inst_ptr + 1);  // 32-bit signed relative offset
            uint32_t return_addr = cpu.eip + 5;         // Calculate return address
            
            // Push return address onto stack (stack grows downward)
            cpu.esp -= 4;
            *(uint32_t*)guest_to_host(cpu.esp) = return_addr;

            // Jump to target address (EIP-relative addressing)
            cpu.eip = cpu.eip + 5 + offset;
        }
        
        // RET - Return from function
        else if (opcode == 0xC3) {
            // Pop return address from stack back into EIP
            cpu.eip = *(uint32_t*)guest_to_host(cpu.esp);
            cpu.esp += 4;  // Restore stack pointer
        }
        
        // INT 0x80 - Software interrupt for Linux system calls
        else if (opcode == 0xCD && *(inst_ptr + 1) == 0x80) {
            handle_syscall(&cpu);  // Delegate to syscall handler
            cpu.eip += 2;          // Advance past 2-byte interrupt instruction
        }
        
        // Unknown instruction - halt emulation with error
        else {
            fprintf(stderr, "[EMU] ERROR: Unknown opcode 0x%02x at EIP 0x%x\n", opcode, cpu.eip);
            exit(1);
        }
    }
}

/**
 * Main Program Entry Point
 * 
 * Handles command line arguments, allocates guest memory, loads ELF binary,
 * and starts emulation. Implements a simple ELF loader that processes
 * program headers and loads segments into guest memory.
 * 
 * @param argc Argument count
 * @param argv Argument vector containing program name and ELF file path
 * @return Exit status code
 */
int main(int argc, char* argv[]) {
    // Validate command line arguments
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <32-bit-elf-executable>\n", argv[0]);
        return 1;
    }

    // Allocate guest memory space using anonymous memory mapping
    g_guest_mem = mmap(NULL, GUEST_MEM_SIZE, PROT_READ | PROT_WRITE, 
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (g_guest_mem == MAP_FAILED) {
        perror("mmap"); 
        return 1;
    }
    printf("[LOADER] Allocated %.1fMB for guest memory.\n", GUEST_MEM_SIZE / (1024.0*1024.0));

    // Open ELF executable file for reading
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) { 
        perror("open"); 
        return 1; 
    }

    // Read and validate ELF header
    Elf32_Ehdr ehdr;
    read(fd, &ehdr, sizeof(ehdr));
    
    // Check ELF magic number and architecture (32-bit)
    if (memcmp(ehdr.e_ident, ELFMAG, SELFMAG) != 0 || ehdr.e_ident[EI_CLASS] != ELFCLASS32) {
        fprintf(stderr, "Not a valid 32-bit ELF file.\n");
        return 1;
    }
    printf("[LOADER] ELF Entry point: 0x%x\n", ehdr.e_entry);

    // Process program headers to load executable segments
    lseek(fd, ehdr.e_phoff, SEEK_SET);  // Seek to program header table
    
    for (int i = 0; i < ehdr.e_phnum; ++i) {
        Elf32_Phdr phdr;
        read(fd, &phdr, sizeof(phdr));
        
        // Only process loadable segments (PT_LOAD)
        if (phdr.p_type == PT_LOAD) {
            printf("[LOADER] Loading segment: vaddr=0x%x, filesz=0x%x\n", 
                   phdr.p_vaddr, phdr.p_filesz);
            
            // Verify segment fits within guest memory bounds
            if (phdr.p_vaddr + phdr.p_memsz > GUEST_MEM_SIZE) {
                fprintf(stderr, "Segment does not fit in guest memory.\n"); 
                return 1;
            }
            
            // Load segment data from file into guest memory
            lseek(fd, phdr.p_offset, SEEK_SET);
            read(fd, guest_to_host(phdr.p_vaddr), phdr.p_filesz);
            
            // Note: p_memsz > p_filesz indicates BSS section (zero-initialized)
            // This is automatically handled since mmap() zero-initializes memory
        }
    }
    close(fd);
    
    // Begin emulation at program entry point
    emulate(ehdr.e_entry);

    return 0;  // This line should never be reached due to emulation loop
}