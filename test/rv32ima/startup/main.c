#include "startup.h"

void main(void) {
    /* After mmu_init, S-mode paging is active */
    /* Test virtual memory: write then read back */
    volatile uint32_t *vaddr = (uint32_t *)0x80001000;
    *vaddr = 0xdeadbeef;
    if (*vaddr != 0xdeadbeef) {
        /* Signal failure to Spike */
        tohost = 1;
    } else {
        /* Signal success to Spike */
        tohost = 0;
    }
    /* Hang so Spike shows the tohost write */
    while (1) {
        asm volatile("wfi");
    }
}
