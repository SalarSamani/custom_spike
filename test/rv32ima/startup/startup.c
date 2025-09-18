#include "startup.h"

/* CSR read/write macros */
#define read_csr(reg) ({ uint32_t __tmp; asm volatile("csrr %0, " #reg : "=r"(__tmp)); __tmp; })
#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" :: "r"(val))

/* MSTATUS field positions */
#define MSTATUS_MPP_SHIFT 11
#define MSTATUS_MPIE      (1 << 7)

/* Page table constants */
#define PGSIZE       4096
#define PT_ENTRIES   1024

/* PTE flag bits */
#define PTE_V        (1U << 0)
#define PTE_R        (1U << 1)
#define PTE_W        (1U << 2)
#define PTE_X        (1U << 3)
#define PTE_A        (1U << 6)
#define PTE_D        (1U << 7)
#define PTE_RWX      (PTE_R | PTE_W | PTE_X)

/*------------------------------------------------------------*/
/* Basic M-mode initialization for switching to S-mode */
static void mstatus_init(void) {
    uint32_t m = read_csr(mstatus);
    /* Set MPP = S-mode (01) */
    m = (m & ~(3U << MSTATUS_MPP_SHIFT)) | (1U << MSTATUS_MPP_SHIFT);
    /* Clear MPIE (disable interrupts on mret) */
    m &= ~MSTATUS_MPIE;
    write_csr(mstatus, m);
}

/* Empty hart initialization (no FPU, no PMP needed here) */
static void hart_init(void) {
    /* nothing for single-core basic setup */
}

/*------------------------------------------------------------*/
/* Hart-Local Storage init stub (single-core) */
void hls_init(uint32_t hartid) {
    (void) hartid;
}

/*------------------------------------------------------------*/
/* Two-level Sv32 page tables */
static uint32_t linear_page_table[256] __attribute__((aligned(4096)));

static uint32_t exp_page_table256[16] __attribute__((aligned(64)));
static uint32_t exp_page_table4k[16] __attribute__((aligned(64)));
static uint32_t exp_page_selector_array[4] __attribute__((aligned(16)));

void mmu_init(void) {

    for (int i = 0; i < 256; i++) {
        linear_page_table[i]        = 0;
    }

    uintptr_t va_base = 0x80000000U;
    uint32_t linear_idx = (va_base >> 24) & 0xFF;

    linear_page_table[linear_idx] = ((uintptr_t)exp_page_selector_array);
    exp_page_selector_array[0] = ((uintptr_t)exp_page_table256);
    exp_page_selector_array[1] = ((uintptr_t)exp_page_table4k);

    for (uint32_t i = 0; i < 16; i++) {
        /* Physical PPN for page */
        uint32_t ppn = ((va_base & 0xFFFFFF00) + 256 * i);
        exp_page_table256[i] = (ppn) | PTE_D | PTE_A | PTE_V | PTE_RWX;
        if (i == 0)
        {
            continue;
        } else {
            ppn = (((va_base) & 0xFFFFFF00) + 4096 * i);
            exp_page_table4k[i] = (ppn) | PTE_D | PTE_A | PTE_V | PTE_RWX;
        }
    }

    uint32_t satp_val = (1U << 31) | (((uintptr_t)linear_page_table) >> 8);
    write_csr(satp, satp_val);

    /* Flush TLB */
    asm volatile("sfence.vma");
}

/*------------------------------------------------------------*/
void init_first_hart(void) {
    /* Prepare M-mode for S-mode transition */
    mstatus_init();
    hart_init();
    hls_init(0);

    /* Set up MMU (two-level) before entering S-mode */
    mmu_init();

    /* Jump to main (assembly label) in S-mode */
    extern void main(void);
    write_csr(mepc, main);
    asm volatile("mret");
    /* Should never return */
    for (;;);
}