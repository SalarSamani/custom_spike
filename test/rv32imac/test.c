/* test.c */

typedef unsigned int uint32_t;
typedef unsigned int uintptr_t;

uint32_t L1_page_table[1024] __attribute__((aligned(4096)));
uint32_t L2_page_table[1024] __attribute__((aligned(4096)));

void setup_page_tables(void) {
    for (int i = 0; i < 1024; i++) {
        L1_page_table[i] = 0;
        L2_page_table[i] = 0;
    }

    // Identity-map 0x80000000–0x80007FFF (8 pages)
    uint32_t phys_base = 0x80000000 >> 12;
    for (int i = 0; i < 8; ++i) {
        uint32_t ppn = phys_base + i;
        L2_page_table[i] = (ppn << 10) | 0xF; // V=1, R=1, W=1, X=1
    }

    // VPN[1] for 0x80000000 is 512
    uintptr_t l2_phys = (uintptr_t)L2_page_table;
    uint32_t l1_pte = (l2_phys >> 12) << 10;
    l1_pte |= 0x1; // V=1, R/W/X=0 (non-leaf)
    L1_page_table[512] = l1_pte;

    // Map VA 0x80200000 → PA 0x80400000
    uint32_t virt = 0x80200000;
    uint32_t phys = 0x80400000;
    uint32_t vpn1 = (virt >> 22) & 0x3FF;  // should still be 512
    uint32_t vpn0 = (virt >> 12) & 0x3FF;
    uint32_t ppn  = phys >> 12;

    // L1[512] already set (points to L2), just set the L2 entry
    L2_page_table[vpn0] = (ppn << 10) | 0x7;  // V=1, R=1, W=1, X=0
}

void main(void) {
    setup_page_tables();
}
