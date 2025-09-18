#!/usr/bin/env bash
set -euo pipefail

# === Prerequisites ===
make

# === Configuration ===
SPIKE_BIN="${SPIKE}/bin/spike"
OPENOCD_BIN="${OPENOCD}/bin/openocd"
GDB_BIN="${RISCV}/bin/riscv32-unknown-elf-gdb"

ELF_FILE="startup.elf"
OPENOCD_CFG="spike.cfg"
RBB_PORT=9824
GDB_PORT=3333

# === Will hold background PIDs ===
SPIKE_PID=0
OPENOCD_PID=0

# === Cleanup function ===
cleanup() {
    echo
    echo "[*] Cleaning up..."
    [[ $OPENOCD_PID -ne 0 ]] && kill "$OPENOCD_PID" 2>/dev/null || true
    [[ $SPIKE_PID     -ne 0 ]] && kill "$SPIKE_PID"     2>/dev/null || true
}
trap cleanup EXIT INT TERM

# === Start Spike (quiet) ===
echo "[*] Starting Spike on RBB port ${RBB_PORT}..."
"$SPIKE_BIN" -m256 --isa=rv32ima_zicsr_zifencei --rbb-port="$RBB_PORT" --halted "$ELF_FILE" \
    &> /dev/null &
SPIKE_PID=$!
sleep 1

# === Start OpenOCD (quiet) ===
echo "[*] Starting OpenOCD (RBB → JTAG bridge)..."
"$OPENOCD_BIN" -f "$OPENOCD_CFG" \
    &> /dev/null &
OPENOCD_PID=$!
sleep 1

# === Launch GDB ===
echo "[*] Launching GDB and connecting to OpenOCD on port ${GDB_PORT}..."
"$GDB_BIN" "$ELF_FILE" \
    -ex "target extended-remote localhost:${GDB_PORT}"

# When GDB exits, the EXIT trap will fire and cleanup() will kill Spike & OpenOCD
