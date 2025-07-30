    .section .text.init
    .global _start
_start:
    # — 1) Set up M-mode stack pointer
    la      sp, stack_top

    # — 2) Delegate traps to S-mode (optional)
    li      t0, 0xBBF
    csrw    medeleg, t0
    li      t0, 0x222
    csrw    mideleg, t0

    # — 3) PMP setup: allow RWX everywhere (NAPOT)
    la      t0, .Lpmp_done        # temp handler 
    csrrw   t1, mtvec, t0         # swap mtvec <-> t1
    li      t2, -1                # pmpaddr0 = 0xFFFF_FFFF
    csrw    pmpaddr0, t2
    li      t2, 0x1F              # pmpcfg0 = NAPOT|R|W|X
    csrw    pmpcfg0, t2
.Lpmp_done:
    csrw    mtvec, t1             # restore real mtvec

    # — 4) Build page tables in C (identity + 0x8020_0000→0x8040_0000)
    call    main

    # — 5) Write test value to physical memory
    li      t0, 0x80400000
    li      t1, 0x12345678
    sw      t1, 0(t0)

    # — 6) Enable Sv32 MMU
    sfence.vma zero, zero
    la      t0, L1_page_table
    srli    t1, t0, 12
    li      t2, 1 << 31           # MODE=1 (Sv32)
    or      t1, t1, t2
    csrw    satp, t1
    sfence.vma zero, zero

    # — 7) Set S-mode trap vector
    la      t0, s_trap_handler
    csrw    stvec, t0

    # — 8) Prepare for MRET → S-mode
    la      t0, s_mode_start
    csrw    mepc, t0              # return to this VA in S-mode

    # clear MPP & MPIE, then set MPP=S-mode
    li      t1, (3 << 11)|(1 << 7)
    csrc    mstatus, t1
    li      t1,    1 << 11
    csrs    mstatus, t1

    mret
    nop

    # — 9) Supervisor entry point (4-byte aligned)
    .balign 4
    .globl  s_mode_start
s_mode_start:
    # In S-mode: load via VA 0x80200000 → PA 0x80400000
    li      t0, 0x80200000
    lw      t1, 0(t0)             # t1 == 0x12345678
    # signal success
    li      a0, 1
    la      t5, tohost
    sw      a0, 0(t5)
1:  j       1b

    # — 10) Simple S-mode trap handler (loops)
    .balign 4
    .globl  s_trap_handler
s_trap_handler:
    j       s_trap_handler

    # — Data sections
    .section .bss
    .align  12
stack:
    .skip   1024
stack_top:

    .section .tohost,"aw",@progbits
    .align  6
    .global tohost
tohost: .dword 0

    .section .fromhost,"aw",@progbits
    .align  6
    .global fromhost
fromhost: .dword 0
