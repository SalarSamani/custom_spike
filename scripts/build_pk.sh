#!/usr/bin/env bash
# =============================================================================
# scripts/build_pk.sh
#
#   Build RISC-V Proxy Kernel (pk) for TARGET_CORE using final toolchain
#   Sources in:     ./tools/pk/source
#   Builds in:      ./tools/pk/build
#   Installs into:  ./tools/pk/install
#
# Usage: build_pk.sh [-t <target>] [-C <core-abi>] [-a <arch>] [-j <jobs>]
#
#   -t <target>      Cross-compile target triple (default: riscv32-unknown-elf)
#   -C <core-abi>    TARGET_CORE identifier (default: rv32imac-ilp32)
#   -a <arch>        ISA string for pk (default: rv32i_zicsr_zifencei)
#   -j <jobs>        Parallel make jobs (default: number of processors)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
PK_ARCH="rv32i_zicsr_zifencei"
JOBS=$(nproc)
PK_REPO="https://github.com/riscv-software-src/riscv-pk.git"
PK_TAG="master"

# ─── Helpers ────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }
usage(){ sed -n '1,20p' "$0"; exit 0; }

# ─── Arg Parsing ─────────────────────────────────────────────────────────────
while getopts ":t:C:a:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG"       ;;
    C) TARGET_CORE="$OPTARG"  ;;
    a) PK_ARCH="$OPTARG"      ;;
    j) JOBS="$OPTARG"         ;;
    h) usage                   ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done

# ─── Derived values ──────────────────────────────────────────────────────────
# (TARGET_CORE -> ARCH and ABI not strictly needed here)

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PK="${ROOT}/tools/pk"
FINAL_PREFIX="${ROOT}/tools/toolchains/${TARGET_CORE}/final/install"
NEWLIB_SYSROOT="${ROOT}/tools/toolchains/${TARGET_CORE}/newlib/install/riscv32-unknown-elf"
SRC_DIR="${BASE_PK}/source"
BUILD_DIR="${BASE_PK}/build"
PREFIX="${BASE_PK}/install"

# ─── Prereq Checks ───────────────────────────────────────────────────────────
for cmd in git make sed patch wget; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required"
done
# Ensure final compiler exists
test -x "${FINAL_PREFIX}/bin/${TARGET}-gcc" || die "Final compiler missing in ${FINAL_PREFIX}"
export PATH="${FINAL_PREFIX}/bin:$PATH"
ok "Prerequisites OK (using final toolchain in ${FINAL_PREFIX})"

# ─── Early Exit if Installed ─────────────────────────────────────────────────
if [[ -x "${PREFIX}/bin/pk" ]]; then
  ok "PK already present in ${PREFIX}"
  exit 0
fi

# ─── Prepare directories ─────────────────────────────────────────────────────
log "Preparing pk dirs under ${BASE_PK}"
mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

# ─── 1) Clone pk source ──────────────────────────────────────────────────────
if [[ ! -d "${SRC_DIR}/.git" ]]; then
  log "Cloning riscv-pk (${PK_TAG})"
  git clone --depth 1 --branch "${PK_TAG}" "$PK_REPO" "$SRC_DIR"
else
  log "Updating riscv-pk source"
  git -C "$SRC_DIR" fetch origin && git -C "$SRC_DIR" checkout "$PK_TAG" && git -C "$SRC_DIR" pull
fi

# ─── 2) Configure pk ─────────────────────────────────────────────────────────
log "Configuring riscv-pk"
cd "$BUILD_DIR"
# Use -nostartfiles to avoid requiring crt0.o, and point includes/libs to newlib + libgcc
CC="${FINAL_PREFIX}/bin/${TARGET}-gcc" \
CFLAGS="--sysroot=${NEWLIB_SYSROOT} -O2 -mcmodel=medany -fno-section-anchors" \
LDFLAGS="-nostartfiles -L${NEWLIB_SYSROOT}/lib -L${FINAL_PREFIX}/lib/gcc/${TARGET}/13.2.0 -lc -lm ${FINAL_PREFIX}/lib/gcc/${TARGET}/13.2.0/libgcc.a" \
"${SRC_DIR}/configure" \
  --prefix="$PREFIX" \
  --host="$TARGET" \
  --with-arch="$PK_ARCH"

# ─── 3) Build & Install pk ─────────────────────────────────────────────────── ───────────────────────────────────────────────────
log "Building riscv-pk"
make -j"${JOBS}"

log "Installing riscv-pk"
make install-strip PREFIX="$PREFIX"

# ─── Verification ────────────────────────────────────────────────────────────
log "Verifying pk installation:"
"${PREFIX}/bin/pk" --version || die "pk not found"
ok "riscv-pk is installed in '${PREFIX}'"
