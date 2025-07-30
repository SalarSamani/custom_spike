#!/usr/bin/env bash
# =============================================================================
# scripts/rebuild_spike.sh
#
#   Rebuild only Spike if its source changed, reinstalling into 
#   tools/spike/{install}, using the existing build tree.
#
# Usage:
#   TARGET_CORE=rv32imac-ilp32 ./scripts/rebuild_spike.sh
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPIKE_DIR="${ROOT}/tools/spike"
SRC_DIR="${SPIKE_DIR}/source"
BUILD_DIR="${SPIKE_DIR}/build"
INSTALL_DIR="${SPIKE_DIR}/install"
STAMP_FILE="${BUILD_DIR}/.last_commit"

# ─── Helpers ─────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }

# ─── 0) Quick checks ──────────────────────────────────────────────────────────
[ -d "$SRC_DIR/.git" ]  || die "Source dir missing: $SRC_DIR"
[ -f "$BUILD_DIR/Makefile" ] || die "Build dir not configured; run build_spike.sh first"
[ -d "$INSTALL_DIR/bin" ]  || die "Install dir missing; run build_spike.sh first"
command -v make >/dev/null || die "make is required"

# ─── 1) Determine current commit ─────────────────────────────────────────────
curr=$(git -C "$SRC_DIR" rev-parse HEAD)
prev=$(<"$STAMP_FILE" 2>/dev/null || echo "")

if [[ "$curr" == "$prev" && -x "$INSTALL_DIR/bin/spike" ]]; then
  ok "Spike up-to-date (commit $curr)"
  exit 0
fi

# ─── 2) Rebuild & reinstall ───────────────────────────────────────────────────
log "Rebuilding Spike (was $prev → now $curr)"
cd "$BUILD_DIR"
make -j"$(nproc)"
make install

# ─── 3) Stamp ─────────────────────────────────────────────────────────────────
echo "$curr" > "$STAMP_FILE"
ok "Spike rebuilt and installed (commit $curr)"

# ─── 4) Verify ───────────────────────────────────────────────────────────────
if [[ -x "$INSTALL_DIR/bin/spike" ]]; then
  ok "Verified: $INSTALL_DIR/bin/spike exists"
else
  die "Error: spike binary missing after rebuild"
fi
