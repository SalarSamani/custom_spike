SHELL := /bin/bash

SRC := test.c startup.S
OUT := test.elf
LINKER := linker.ld

CFLAGS := -march=rv32ima_zicsr_zbkb_zbkx_zkne_zknd_zknh \
          -mabi=ilp32 \
          -static \
          -mcmodel=medany \
          -nostdlib \
          -nostartfiles \
          -g \
          -o0

LDFLAGS := -T $(LINKER)

all: $(OUT)

$(OUT): $(SRC) $(LINKER)
	$(RISCV)/bin/riscv32-unknown-elf-gcc $(CFLAGS) $(LDFLAGS) $(SRC) -o $(OUT)

clean:
	rm -f $(OUT)

.PHONY: all clean env
