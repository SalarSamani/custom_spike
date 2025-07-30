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
static uint32_t root_page_table[PT_ENTRIES] __attribute__((aligned(PGSIZE)));
static uint32_t second_level_table[PT_ENTRIES] __attribute__((aligned(PGSIZE)));

void mmu_init(void) {
    /* Clear all root and second-level entries */
    for (int i = 0; i < PT_ENTRIES; i++) {
        root_page_table[i]        = 0;
        second_level_table[i]     = 0;
    }

    /* Calculate indices for VA = 0x80000000 */
    uintptr_t va_base = 0x80000000U;
    uint32_t vpn1 = (va_base >> 22) & 0x3FF;
    uint32_t vpn0 = (va_base >> 12) & 0x3FF;
    uint32_t ppn_root = ((uintptr_t)root_page_table) >> 12;
    uint32_t ppn_2nd  = ((uintptr_t)second_level_table) >> 12;

    /* Root: point vpn1 to second-level table */
    root_page_table[vpn1] = (ppn_2nd << 10) | PTE_V;

    /* Second level: identity-map 256 KiB = 64 pages */
    for (uint32_t i = 0; i < 64; i++) {
        /* Physical PPN for page */
        uint32_t ppn = ((va_base >> 12) + i);
        second_level_table[vpn0 + i] = (ppn << 10) | PTE_D | PTE_A | PTE_V | PTE_RWX;
    }

    /* Write SATP: MODE=1 (Sv32), ASID=0, PPN = root_table PPN */
    uint32_t satp_val = (1U << 31) | ppn_root;
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