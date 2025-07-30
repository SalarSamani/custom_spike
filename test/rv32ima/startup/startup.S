    .option norvc

    /* Machine-mode reset and startup */
    .section .text.init
    .align  2
    .globl  reset_vector
reset_vector:
    /* Entry point after reset */
    j   do_reset

    .globl  trap_vector
trap_vector:
    /* Simple trap handler—just wait here forever */
    wfi
    j   trap_vector

    .globl  do_reset
    .align  2
do_reset:
    /* Zero x1–x9 */
    li x1,0
    li x2,0
    li x3,0
    li x4,0
    li x5,0
    li x6,0
    li x7,0
    li x8,0
    li x9,0
    li x10,0
    li x11,0
    li x12,0
    li x13,0
    li x14,0
    li x15,0
    li x16,0
    li x17,0
    li x18,0
    li x19,0
    li x20,0
    li x21,0
    li x22,0
    li x23,0
    li x24,0
    li x25,0
    li x26,0
    li x27,0
    li x28,0
    li x29,0
    li x30,0
    li x31,0

    /* Clear mscratch */
    csrw    mscratch, x0

    /* Set mtvec = trap_vector */
    la      t0, trap_vector
    csrw    mtvec, t0
    csrr    t1, mtvec
1:  bne     t0, t1, 1b        /* Ensure it stuck */

    /* Set up a 4 KiB stack for hart 0 */
    la      sp, stacks + 4096

    /* Jump to C init */
    j       init_first_hart

    /* Data section for hart stack */
    .section .bss
    .align 12                 /* 4096-byte align */
    .globl  stacks
stacks:
    .skip   4096              /* One page for our stack */

    /* Simple exit code for Spike */
    .section .text.exit
    .align  2
exit:
    li      a0, 1
    la      t5, tohost
    sw      a0, 0(t5)
1:  j       1b


    /* Spike exit symbols */
    .section .tohost,"aw",@progbits
    .align  6
    .global tohost
tohost: .dword 0

    .section .fromhost,"aw",@progbits
    .align  6
    .global fromhost
fromhost: .dword 0

