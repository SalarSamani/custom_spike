#!/usr/bin/env bash
# =============================================================================
# scripts/rebuild_spike.sh
#
#   Incrementally rebuild Spike from existing source tree in tools/spike/source
#   Only recompiles changed files and relinks (normal Make behavior)
#
# Usage:
#   TARGET_CORE=rv32imac-ilp32 ./scripts/rebuild_spike.sh
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Configuration ────────────────────────────────────────────────────────────
JOBS=$(nproc)
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPIKE_DIR="${ROOT}/tools/spike"
SRC_DIR="${SPIKE_DIR}/source"
BUILD_DIR="${SPIKE_DIR}/build"
INSTALL_DIR="${SPIKE_DIR}/install"

# ─── Helpers ─────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }

# ─── Ensure build directory and configure ───────────────────────────────────
if [[ ! -d "$SRC_DIR" ]]; then
  die "Spike source directory not found. Run build_spike.sh first."
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Run configure only once
if [[ ! -f Makefile ]]; then
  log "Configuring Spike build (first-time)"
  "$SRC_DIR/configure" --prefix="$INSTALL_DIR"
  ok "Configuration complete"
fi

# ─── Incremental build & install ──────────────────────────────────────────────
log "Building Spike incrementally (jobs=$JOBS)"
make -j"$JOBS"
ok "Build complete"

log "Installing Spike to ${INSTALL_DIR}"
make install
ok "Installation complete"

# ─── Verify build ─────────────────────────────────────────────────────────────
if [[ -x "${INSTALL_DIR}/bin/spike" ]]; then
  ok "Spike binary is present at ${INSTALL_DIR}/bin/spike"
else
  die "Spike binary missing after rebuild"
fi
