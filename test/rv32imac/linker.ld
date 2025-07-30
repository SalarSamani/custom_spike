OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS {
  . = 0x80000000;

  .text : {
    *(.text)
    *(.rodata*)
  }

  . = ALIGN(0x1000);
  .data : {
    *(.data)
  }

  . = ALIGN(0x1000);
  .bss : {
    __bss_start = .;
    *(.bss)
    *(COMMON)
    __bss_end = .;
  }

  _end = .;
}
