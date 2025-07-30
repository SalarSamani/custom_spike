#!/usr/bin/env bash
# =============================================================================
# scripts/build_toolchain_initial.sh
#
#   Stage 1: Build binutils → GCC (initial)
#   Sources in:     ./tools/toolchains/${TARGET_CORE}/initial/source
#   Builds in:      ./tools/toolchains/${TARGET_CORE}/initial/build
#   Installs into:  ./tools/toolchains/${TARGET_CORE}/initial/install
#
# Usage: build_toolchain_initial.sh [-t <target>] [-C <core-abi>] \
#                                   [-B <binutils-branch>] [-g <gcc-ref>] \
#                                   [-j <jobs>]
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
BINUTILS_REF="binutils-2_44"
GCC_REF="releases/gcc-14.2.0"
JOBS=$(nproc)

# ─── Helpers ────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }
usage(){
  sed -n '1,50p' "$0" | sed 's/^# \?//'
  exit 0
}

# ─── Arg Parsing ─────────────────────────────────────────────────────────────
while getopts ":t:C:B:g:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG"       ;;
    C) TARGET_CORE="$OPTARG"  ;;
    B) BINUTILS_REF="$OPTARG" ;;
    g) GCC_REF="$OPTARG"      ;;
    j) JOBS="$OPTARG"         ;;
    h) usage                   ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done

# ─── Derive ARCH/ABI from TARGET_CORE ────────────────────────────────────────
ARCH="${TARGET_CORE%%-*}"
ABI="${TARGET_CORE#*-}"

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${ROOT}/tools/toolchains/${TARGET_CORE}/initial"
SRC_DIR="${BASE_DIR}/source"
BUILD_DIR="${BASE_DIR}/build"
PREFIX="${BASE_DIR}/install"

BINUTILS_SRC="${SRC_DIR}/binutils-gdb"
GCC_SRC="${SRC_DIR}/gcc"
PATCH_DIR="${ROOT}/patches"

BUILD_BINUTILS="${BUILD_DIR}/binutils"
BUILD_GCC="${BUILD_DIR}/gcc"

# ─── Prereq Checks ───────────────────────────────────────────────────────────
for cmd in git wget make sed patch; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required"
done
ok "Prerequisites OK"

# ─── Early Exit if Installed ────────────────────────────────────────────────
if [[ -x "${PREFIX}/bin/${TARGET}-gcc" && -x "${PREFIX}/bin/${TARGET}-ld" ]]; then
  ok "Initial toolchain already present in ${PREFIX}"
  exit 0
fi

# ─── Prepare directories ─────────────────────────────────────────────────────
log "Preparing directories under ${BASE_DIR}"
mkdir -p \
  "${SRC_DIR}" \
  "${BUILD_DIR}" \
  "${PREFIX}"

# ─── 1) BINUTILS ─────────────────────────────────────────────────────────────
if [[ ! -d "${BINUTILS_SRC}/.git" ]]; then
  log "Cloning binutils-gdb (${BINUTILS_REF})"
  git clone --depth 1 --branch "${BINUTILS_REF}" \
    https://sourceware.org/git/binutils-gdb.git "${BINUTILS_SRC}"
else
  log "Updating binutils-gdb to ${BINUTILS_REF}"
  git -C "${BINUTILS_SRC}" fetch origin
  git -C "${BINUTILS_SRC}" checkout "${BINUTILS_REF}"
  git -C "${BINUTILS_SRC}" pull
fi

# Apply patches if any
if compgen -G "${PATCH_DIR}/binutils/*.patch" >/dev/null; then
  log "Applying binutils patches"
  pushd "${BINUTILS_SRC}" >/dev/null
    for p in "${PATCH_DIR}/binutils/"*.patch; do
      patch -p1 < "$p"
    done
  popd >/dev/null
fi

log "Building binutils"
mkdir -p "${BUILD_BINUTILS}" && cd "${BUILD_BINUTILS}"
"${BINUTILS_SRC}/configure" \
  --prefix="${PREFIX}" \
  --target="${TARGET}" \
  --disable-nls \
  --disable-multilib
make -j"${JOBS}"
make install
cd "${ROOT}"
ok "Binutils done"

# ─── 2) GCC Stage 1 ─────────────────────────────────────────────────────────
if [[ ! -d "${GCC_SRC}/.git" ]]; then
  log "Cloning GCC (${GCC_REF})"
  git clone --depth 1 --branch "${GCC_REF}" \
    https://gcc.gnu.org/git/gcc.git "${GCC_SRC}"
else
  log "Updating GCC to ${GCC_REF}"
  git -C "${GCC_SRC}" fetch origin
  git -C "${GCC_SRC}" checkout "${GCC_REF}"
  git -C "${GCC_SRC}" pull
fi

# Apply patches if any
if compgen -G "${PATCH_DIR}/gcc/*.patch" >/dev/null; then
  log "Applying GCC patches"
  pushd "${GCC_SRC}" >/dev/null
    for p in "${PATCH_DIR}/gcc/"*.patch; do
      patch -p1 < "$p"
    done
  popd >/dev/null
fi

log "Downloading GCC prerequisites"
pushd "${GCC_SRC}" >/dev/null
  ./contrib/download_prerequisites
popd >/dev/null

log "Building GCC (C only)"
mkdir -p "${BUILD_GCC}" && cd "${BUILD_GCC}"
"${GCC_SRC}/configure" \
  --prefix="${PREFIX}" \
  --target="${TARGET}" \
  --with-arch="${ARCH}_zicsr_zifencei" \
  --with-abi="${ABI}" \
  --disable-shared \
  --disable-threads \
  --disable-multilib \
  --with-newlib \
  --without-headers \
  --enable-languages=c

make all-gcc -j"${JOBS}"
make all-target-libgcc -j"${JOBS}"
make install-gcc
make install-target-libgcc
cd "${ROOT}"
ok "GCC Stage 1 done"

# ─── Verification ────────────────────────────────────────────────────────────
log "Verifying initial toolchain:"
"${PREFIX}/bin/${TARGET}-gcc" --version | head -n1
"${PREFIX}/bin/${TARGET}-ld"  --version | head -n1
ok "Initial toolchain installed in '${PREFIX}'"
