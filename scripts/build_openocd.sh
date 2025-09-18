#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─── Configuration ────────────────────────────────────────────────────────────
REPO="https://github.com/salarsamani/riscv-openocd.git"
# BRANCH="riscv"
BRANCH="scalable_mmu"
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
  log "Cloning riscv-openocd ($BRANCH)…"
  git clone --recursive "$REPO" "$SRC_DIR"
  cd "$SRC_DIR"
  git checkout "$BRANCH"
else
  log "Updating riscv-openocd…"
  cd "$SRC_DIR"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull --ff-only
  git submodule update --init --recursive
fi

# ─── 3) Bootstrap to generate configure ─────────────────────────────────────────
cd "$SRC_DIR"
if [ -x ./bootstrap ]; then
  log "Running ./bootstrap"
  libtoolize --install
  ./bootstrap
else
  log "No bootstrap script; assuming 'configure' is already present"
fi

# ─── 4) Verify configure exists ─────────────────────────────────────────────────
[ -x "$SRC_DIR/configure" ] || die "'configure' not found in $SRC_DIR after bootstrap"

# ─── 5) Configure in an out-of-source build ────────────────────────────────────
log "Configuring in $BUILD_DIR"
cd "$BUILD_DIR"
"$SRC_DIR/configure" \
  --prefix="$INSTALL_DIR" \
  --enable-ftdi \
  --enable-internal-jimtcl \
  --disable-werror

# ─── 6) Build & install ───────────────────────────────────────────────────────
log "Building OpenOCD"
make -j"$(nproc)"

log "Installing to $INSTALL_DIR"
make install

# ─── 7) Verify ─────────────────────────────────────────────────────────────────
[ -x "$INSTALL_DIR/bin/openocd" ] || die "Build succeeded but no binary at $INSTALL_DIR/bin/openocd"
log "OpenOCD built and installed to $INSTALL_DIR/bin/openocd"
