#!/usr/bin/env bash
# =============================================================================
# setup_env.sh
#
#   Environment setup for RISC-V toolchain, OpenOCD, and Spike
#   Use: source setup_env.sh [-C <core-abi>]
#
#   -C <core-abi>    TARGET_CORE (default: rv32imac-ilp32)
#
#   Sets these variables:
#     RISCV     → Toolchain install dir
#     OPENOCD   → OpenOCD install dir
#     SPIKE     → Spike install dir
#
#   Also updates:
#     PATH            → Adds ${RISCV}/bin, ${OPENOCD}/bin, ${SPIKE}/bin
#     LD_LIBRARY_PATH → Adds ${RISCV}/lib and ${RISCV}/lib64
# =============================================================================

# ─── Safe Defaults ───────────────────────────────────────────────────────────
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"

# ─── Arg Parsing ─────────────────────────────────────────────────────────────
while getopts ":C:h" opt; do
  case "$opt" in
    C) TARGET_CORE="$OPTARG" ;;
    h)
      echo "Usage: source setup_env.sh [-C <core-abi>]"
      return 0
      ;;
    *) echo "Unknown option -$OPTARG"; return 1 ;;
  esac
done

# ─── Logging ─────────────────────────────────────────────────────────────────
is_sourced() { [[ "${BASH_SOURCE[0]}" != "${0}" ]]; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }

# ─── Resolve Paths ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RISCV="${SCRIPT_DIR}/../tools/toolchains/${TARGET_CORE}/final/install"
export OPENOCD="${SCRIPT_DIR}/../tools/openocd/install"
export SPIKE="${SCRIPT_DIR}/../tools/spike/install"

# ─── Check Directories ───────────────────────────────────────────────────────
[[ -d "${RISCV}" ]]   || log "Warning: RISCV path '${RISCV}' does not exist"
[[ -d "${OPENOCD}" ]] || log "Warning: OPENOCD path '${OPENOCD}' does not exist"
[[ -d "${SPIKE}" ]]   || log "Warning: SPIKE path '${SPIKE}' does not exist"

# ─── Update PATH ─────────────────────────────────────────────────────────────
export PATH="${RISCV}/bin:${OPENOCD}/bin:${SPIKE}/bin:${PATH}"
log "Updated PATH with toolchain, OpenOCD, and Spike binaries"

# ─── Update LD_LIBRARY_PATH ──────────────────────────────────────────────────
export LD_LIBRARY_PATH="${RISCV}/lib:${RISCV}/lib64:${LD_LIBRARY_PATH:-}"
log "Updated LD_LIBRARY_PATH with RISCV libraries"

# ─── Final Status ────────────────────────────────────────────────────────────
log "Environment variables set:"
echo "  RISCV    = ${RISCV}"
echo "  OPENOCD  = ${OPENOCD}"
echo "  SPIKE    = ${SPIKE}"

ok "Environment setup complete for TARGET_CORE=${TARGET_CORE}"
