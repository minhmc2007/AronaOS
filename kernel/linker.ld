/* 64-bit Linker Script */
ENTRY(kernel_main)
OUTPUT_FORMAT(elf64-x86-64)

SECTIONS {
    . = 1M; /* Kernel starts at 1MB */

    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }

    /DISCARD/ : { *(.comment) *(.eh_frame) }
}