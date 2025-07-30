#ifndef STARTUP_H
#define STARTUP_H

/* Minimal types */
// typedef unsigned int        uint32_t;
// typedef unsigned int uintptr_t;

#include <stdint.h>

/* Entry point after reset */
void init_first_hart(void);

/* Hart-local storage stub (no-op for single core) */
void hls_init(uint32_t hartid);

/* MMU setup before entering S-mode */
void mmu_init(void);

/* tohost for Spike exit */
extern volatile uint32_t tohost;

#endif /* STARTUP_H */
