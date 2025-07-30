OUTPUT_ARCH("riscv")
ENTRY(reset_vector)

SECTIONS {
  . = 0x80000000;

  .tohost_fromhost : {
    KEEP(*(.tohost))
    KEEP(*(.fromhost))
  } :tohost_mem

  . = ALIGN(16);

  .text : {
    *(.text.init)
    *(.text)
    *(.rodata*)
  } :text_mem

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

PHDRS {
  tohost_mem PT_LOAD FLAGS( RW );
  text_mem   PT_LOAD FLAGS( RX );
}
