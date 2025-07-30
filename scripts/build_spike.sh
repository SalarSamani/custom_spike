# === scripts/build_spike.sh ===
#!/usr/bin/env bash
# =============================================================================
# scripts/build_spike.sh
#
#   Clone & build Spike (riscv-isa-sim) from SalarSamani fork on branch scalable_mmu
#   into tools/spike/{source,build,install}
#   Installs only the `spike` simulator (no proxy kernel)
#
# Usage:
#   TARGET_CORE=rv32imac-ilp32 ./scripts/build_spike.sh
#   TARGET_CORE=rv64gc-lp64   ./scripts/build_spike.sh
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Configuration ────────────────────────────────────────────────────────────
REPO="https://github.com/SalarSamani/riscv-isa-sim.git"
BRANCH="scalable_mmu"
JOBS=$(nproc)
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RISCV="${ROOT}/tools/toolchains/${TARGET_CORE}/final/install"
SPIKE_DIR="${ROOT}/tools/spike"
SRC_DIR="${SPIKE_DIR}/source"
BUILD_DIR="${SPIKE_DIR}/build"
INSTALL_DIR="${SPIKE_DIR}/install"

# ─── Helpers ─────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }

# ─── 0) Verify final toolchain prefix ────────────────────────────────────────
[ -d "$RISCV" ] || die "Final toolchain not found at '$RISCV'. Build it first."
export RISCV
export PATH="$RISCV/bin:$PATH"
ok "Using final toolchain: $RISCV"

# ─── 1) Check minimal build tools ─────────────────────────────────────────────
for cmd in git make g++ autoconf automake libtoolize pkg-config dtc; do
  command -v "$cmd" >/dev/null || die "Prerequisite '$cmd' is missing"
done
ok "All build tools present"

# ─── 2) Prepare spike directories ─────────────────────────────────────────────
log "Resetting Spike dirs under $SPIKE_DIR"
rm -rf "$SPIKE_DIR"
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_DIR"

# ─── 3) Clone or update Spike source ─────────────────────────────────────────
if [[ ! -d "$SRC_DIR/.git" ]]; then
  log "Cloning riscv-isa-sim (fork SalarSamani, branch $BRANCH)"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$SRC_DIR"
else
  log "Updating local source from fork SalarSamani, branch $BRANCH"
  git -C "$SRC_DIR" fetch origin "$BRANCH"
  git -C "$SRC_DIR" checkout "$BRANCH"
  git -C "$SRC_DIR" pull --ff-only
  git -C "$SRC_DIR" submodule update --init --recursive
fi

# ─── 4) Bootstrap & configure ─────────────────────────────────────────────────
log "Bootstrapping (autoreconf -i)"
cd "$SRC_DIR"
autoreconf -i

log "Configuring in $BUILD_DIR"
cd "$BUILD_DIR"
"$SRC_DIR/configure" \
  --prefix="$INSTALL_DIR"

# ─── 5) Build & install ──────────────────────────────────────────────────────
log "Building (jobs=$JOBS)"
make -j"$JOBS"

log "Installing spike only"
make install

# ─── 6) Verify only spike binary ──────────────────────────────────────────────
if [[ -x "$INSTALL_DIR/bin/spike" ]]; then
  ok "Spike built and installed to $INSTALL_DIR/bin/spike"
else
  die "Spike build succeeded, but '$INSTALL_DIR/bin/spike' is missing"
fi

# ─── Optional cleanup ─────────────────────────────────────────────────────────
pushd "$SRC_DIR" >/dev/null
git restore config.h.in >/dev/null 2>&1 || true
popd >/dev/null