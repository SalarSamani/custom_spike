#!/usr/bin/env bash
# =============================================================================
# scripts/build_toolchain_final.sh
#
#   Stage 3: Build final Binutils + GCC (with Newlib) + GDB for TARGET_CORE
#   Sources in:     ./tools/toolchains/${TARGET_CORE}/final/source
#   Builds in:      ./tools/toolchains/${TARGET_CORE}/final/build
#   Installs into:  ./tools/toolchains/${TARGET_CORE}/final/install
#
# Usage: build_toolchain_final.sh [-t <target>] [-C <core-abi>] [-j <jobs>]
#
#   -t <target>      Cross-compile target triple (default: riscv32-unknown-elf)
#   -C <core-abi>    TARGET_CORE (default: rv32imac-ilp32)
#   -j <jobs>        Parallel make jobs (default: number of processors)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
JOBS=$(nproc)
GDB_VER="15.2"

# ─── Helpers ────────────────────────────────────────────────────────────────
die()  { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log()  { echo -e "\e[1;34m➤\e[0m $*"; }
ok()   { echo -e "\e[1;32m✔\e[0m $*"; }

# ─── Arg Parsing ─────────────────────────────────────────────────────────────
while getopts ":t:C:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG"       ;;
    C) TARGET_CORE="$OPTARG"  ;;
    j) JOBS="$OPTARG"         ;;
    h) die "Usage: $0 [-t <target>] [-C <core-abi>] [-j <jobs>]" ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done

# ─── Derived values ──────────────────────────────────────────────────────────
ARCH="${TARGET_CORE%%-*}"
ABI="${TARGET_CORE#*-}"

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${ROOT}/tools/toolchains/${TARGET_CORE}"
INIT_PREFIX="${BASE_DIR}/initial/install"
NEWLIB_PREFIX="${BASE_DIR}/newlib/install/${TARGET}"
SRC_DIR="${BASE_DIR}/final/source"
BUILD_DIR="${BASE_DIR}/final/build"
PREFIX="${BASE_DIR}/final/install"

# ─── Prereq Checks ───────────────────────────────────────────────────────────
for cmd in make sed patch wget tar; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required"
done
# Ensure bootstrap toolchain exists
test -x "${INIT_PREFIX}/bin/${TARGET}-gcc" || die "Initial compiler missing in ${INIT_PREFIX}"
test -d  "${NEWLIB_PREFIX}/include"  || die "Newlib headers missing in ${NEWLIB_PREFIX}"
export PATH="${INIT_PREFIX}/bin:$PATH"
ok "Prerequisites OK"

# ─── Early Exit if Installed ─────────────────────────────────────────────────
if [[ -x "${PREFIX}/bin/${TARGET}-gcc" && -x "${PREFIX}/bin/${TARGET}-gdb" ]]; then
  ok "Final toolchain already present in ${PREFIX}"; exit 0
fi

# ─── Prepare directories ─────────────────────────────────────────────────────
log "Preparing final dirs under ${PREFIX}"
mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

# ─── 1) Copy Binutils source from initial ─────────────────────────────────────
log "Copying Binutils source from initial stage"
mkdir -p "${SRC_DIR}/binutils-gdb"
cp -a "${BASE_DIR}/initial/source/binutils-gdb/." "${SRC_DIR}/binutils-gdb/"

# ─── 2) Build Final Binutils ─────────────────────────────────────────────────
log "Configuring and building final Binutils"
mkdir -p "${BUILD_DIR}/binutils" && cd "${BUILD_DIR}/binutils"
"${SRC_DIR}/binutils-gdb/configure" \
  --prefix="${PREFIX}" \
  --target="${TARGET}" \
  --disable-nls \
  --disable-multilib
make -j"${JOBS}"
make install
ok "Binutils installed in ${PREFIX}"

# ─── 3) Copy Newlib sysroot ──────────────────────────────────────────────────
log "Copying Newlib sysroot (headers, libs)"
mkdir -p "${PREFIX}/${TARGET}"
cp -a "${NEWLIB_PREFIX}/." "${PREFIX}/${TARGET}/"

# ─── 4) Copy GCC source ─────────────────────────────────────────────────────
log "Copying GCC sources for final stage"
mkdir -p "${SRC_DIR}/gcc"
cp -a "${BASE_DIR}/initial/source/gcc/." "${SRC_DIR}/gcc/"

# ─── 5) Configure & Build final GCC ──────────────────────────────────────────
log "Configuring final GCC (with Newlib)"
mkdir -p "${BUILD_DIR}/gcc" && cd "${BUILD_DIR}/gcc"
"${SRC_DIR}/gcc/configure" \
  --prefix="${PREFIX}" \
  --target="${TARGET}" \
  --with-arch="${ARCH}_zicsr_zifencei" \
  --with-abi="${ABI}" \
  --disable-shared \
  --disable-threads \
  --disable-multilib \
  --with-newlib \
  --enable-languages=c,c++

log "Building final GCC"
make -j"${JOBS}"
log "Installing final GCC"
make install

# ─── 6) Download & Extract GDB ───────────────────────────────────────────────
log "Fetching GDB ${GDB_VER}"
mkdir -p "${SRC_DIR}/gdb" && cd "${SRC_DIR}/gdb"
if [[ ! -f "gdb-${GDB_VER}.tar.xz" ]]; then
  wget -c "https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VER}.tar.xz"
fi
if [[ ! -f "configure" ]]; then
  tar --strip-components=1 -xf "gdb-${GDB_VER}.tar.xz" -C "${SRC_DIR}/gdb"
fi

# ─── 7) Configure & Build GDB ────────────────────────────────────────────────
log "Configuring GDB"
mkdir -p "${BUILD_DIR}/gdb" && cd "${BUILD_DIR}/gdb"
"${SRC_DIR}/gdb/configure" --prefix="${PREFIX}" --target="${TARGET}"

log "Building GDB"
make -j"${JOBS}"
log "Installing GDB"
make install

# ─── Verification ────────────────────────────────────────────────────────────
log "Verifying final toolchain:"
"${PREFIX}/bin/${TARGET}-gcc" --version | head -n1
"${PREFIX}/bin/${TARGET}-ld"  --version | head -n1
"${PREFIX}/bin/${TARGET}-gdb" --version | head -n1
ok "Final toolchain ready at ${PREFIX}"
