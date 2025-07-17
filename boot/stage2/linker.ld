/* 64-bit Linker Script */
ENTRY(preKernelMain)
OUTPUT_FORMAT(elf32-i386)

SECTIONS {
    . = 0x8400;

    .text : { 
        *(.text.entry)
        *(.text) 
    }

    .rodata (READONLY) : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }

    /DISCARD/ : { *(.comment) *(.eh_frame) }

    end = .;
}