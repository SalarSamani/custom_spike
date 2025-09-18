#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─── Configuration ────────────────────────────────────────────────────────────
REPO="https://github.com/riscv-collab/riscv-openocd.git"
BRANCH="riscv"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_BASE="$ROOT/tools/openocd"
SRC_DIR="$TOOLS_BASE/source"
BUILD_DIR="$TOOLS_BASE/build"
INSTALL_DIR="$TOOLS_BASE/install"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log() { echo -e "\e[1;34m➤\e[0m $*"; }
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }

# ─── 0) Check prerequisites ────────────────────────────────────────────────────
for cmd in git autoconf automake libtoolize pkg-config make patch; do
  command -v "$cmd" >/dev/null || die "Install prerequisite: $cmd"
done
log "Prerequisites OK"

# ─── 1) Prepare directories ─────────────────────────────────────────────────────
log "Creating directories"
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"

# ─── 2) Clone or update the RISC-V fork ─────────────────────────────────────────
if [ ! -d "$SRC_DIR/.git" ]; then
  die "Source tree not found at $SRC_DIR (no .git). Run the full setup first."
else
  log "Using existing riscv-openocd source (incremental rebuild); skipping fetch/pull"
  cd "$SRC_DIR"
fi

# ─── 3) Bootstrap to generate configure ─────────────────────────────────────────
cd "$SRC_DIR"
if [ -x ./bootstrap ]; then
  log "Skipping ./bootstrap for incremental rebuild"
  # libtoolize --install
  # ./bootstrap
else
  log "No bootstrap script; assuming 'configure' is already present"
fi

# ─── 4) Verify configure exists ─────────────────────────────────────────────────
[ -x "$SRC_DIR/configure" ] || die "'configure' not found in $SRC_DIR after bootstrap"

# ─── 5) Configure in an out-of-source build ────────────────────────────────────
log "Configuring in $BUILD_DIR"
cd "$BUILD_DIR"
if [ -f Makefile ]; then
  log "Skipping configure (incremental rebuild); existing Makefile detected"
else
  die "No existing build configuration in $BUILD_DIR. Run the full configure step first."
fi

# ─── 6) Build & install ───────────────────────────────────────────────────────
log "Building OpenOCD"
make -j"$(nproc)"

log "Installing to $INSTALL_DIR"
make install

# ─── 7) Verify ─────────────────────────────────────────────────────────────────
[ -x "$INSTALL_DIR/bin/openocd" ] || die "Build succeeded but no binary at $INSTALL_DIR/bin/openocd"
log "OpenOCD built and installed to $INSTALL_DIR/bin/openocd"
