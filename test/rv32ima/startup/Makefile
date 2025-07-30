SHELL := /bin/bash

# ─── Source and Target ───────────────────────────────────────────────────────
SRC := main.S startup.c startup.S
OUT := startup.elf
LINKER := linker.ld

# ─── Flags ───────────────────────────────────────────────────────────────────
CFLAGS := -march=rv32ima_zicsr_zbkb_zbkx_zkne_zknd_zknh \
          -mabi=ilp32 \
          -static \
          -mcmodel=medany \
          -nostdlib \
          -nostartfiles \
          -g \
          -O0

LDFLAGS := -T $(LINKER)

# ─── Build Rules ─────────────────────────────────────────────────────────────
all: $(OUT)

$(OUT): $(SRC) $(LINKER)
	$(RISCV)/bin/riscv32-unknown-elf-gcc $(CFLAGS) $(LDFLAGS) $(SRC) -o $(OUT)

clean:
	rm -f $(OUT)

.PHONY: all clean
