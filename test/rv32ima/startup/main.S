    .section .text
    .globl main
main:
    li t0, 0xDEADBEEF         # Load test value
    la t1, 0x80001000         # A valid VA in the mapped region
    sw t0, 0(t1)              # Store test value
    lw t2, 0(t1)              # Load it back

1:  j 1b                      # Infinite loop — check t2 in GDB