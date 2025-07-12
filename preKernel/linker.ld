/* 64-bit Linker Script */
ENTRY(preKernelMain)
OUTPUT_FORMAT(elf64-x86-64)

SECTIONS {
    . = 0x8000; /* free area as bios specifications */

    .text : { 
        *(.text.entry)
        *(.text) 
    }

    .rodata (READONLY) : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }

    /DISCARD/ : { *(.comment) *(.eh_frame) }
}