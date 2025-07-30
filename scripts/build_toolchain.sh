#!/usr/bin/env bash
# =============================================================================
# scripts/build_toolchain_initial.sh
#
#   Stage 1: Build binutils + GCC (compiler-only) for TARGET_CORE
#   Layout: tools/toolchains/${TARGET_CORE}/initial/{source,build,install}
#
# Usage:
#   TARGET_CORE=rv32imac-ilp32 bash scripts/build_toolchain_initial.sh
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults & Args ──────────────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
BINUTILS_REF="binutils-2_44"
GCC_REF="releases/gcc-13.2.0"
GDB_VER="13.2"
JOBS=$(nproc)

# Parse options (if you need)
while getopts ":t:C:B:g:d:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG";;
    C) TARGET_CORE="$OPTARG";;
    B) BINUTILS_REF="$OPTARG";;
    g) GCC_REF="$OPTARG";;
    d) GDB_VER="$OPTARG";;
    j) JOBS="$OPTARG";;
    h) echo "Usage: $0 [-t target] [-C core] [-B binutils] [-g gcc] [-d gdb] [-j jobs]"; exit 0;;
    *) echo "Unknown option -$OPTARG" >&2; exit 1;;
  esac
done

# Derive ARCH/ABI
ARCH="${TARGET_CORE%%-*}"
ABI="${TARGET_CORE#*-}"

# Paths
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${ROOT}/tools/toolchains/${TARGET_CORE}"
SRC_DIR="${BASE}/initial/source"
BUILD_DIR="${BASE}/initial/build"
PREFIX="${BASE}/initial/install"

BINUTILS_SRC="${SRC_DIR}/binutils-gdb"
GCC_SRC="${SRC_DIR}/gcc"
GDB_ARCHIVE="${SRC_DIR}/gdb-${GDB_VER}.tar.gz"
GDB_SRC="${SRC_DIR}/gdb-${GDB_VER}"

BUILD_BINUTILS="${BUILD_DIR}/binutils"
BUILD_GCC="${BUILD_DIR}/gcc"
BUILD_GDB="${BUILD_DIR}/gdb"

PATCH_DIR="${ROOT}/patches"

# Helpers
log(){ echo -e "\e[1;34m➤\e[0m $*"; }
die(){ echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
ok(){ echo -e "\e[1;32m✔\e[0m $*"; }

# Prereqs
for cmd in git wget make sed patch; do
  command -v "$cmd" >/dev/null || die "$cmd is required"
done
ok "Prerequisites OK"

# Early exit
if [[ -x "${PREFIX}/bin/${TARGET}-gcc" && -x "${PREFIX}/bin/${TARGET}-ld" ]]; then
  ok "Initial toolchain already present in ${PREFIX}"
  exit 0
fi

# Prepare dirs
log "Preparing initial dirs under ${BASE}/initial"
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$PREFIX"

# 1) BINUTILS
log "Cloning binutils-gdb (${BINUTILS_REF})"
if [[ ! -d "$BINUTILS_SRC/.git" ]]; then
  git clone --depth 1 --branch "$BINUTILS_REF" \
    https://sourceware.org/git/binutils-gdb.git "$BINUTILS_SRC"
else
  log "Updating binutils"
  git -C "$BINUTILS_SRC" fetch origin && git -C "$BINUTILS_SRC" checkout "$BINUTILS_REF"
fi

log "Building binutils"
mkdir -p "$BUILD_BINUTILS" && cd "$BUILD_BINUTILS"
"$BINUTILS_SRC/configure" --prefix="$PREFIX" --target="$TARGET" --disable-nls --disable-multilib
make -j"$JOBS" install

# 2) GCC (stage1)
log "Cloning GCC (${GCC_REF})"
if [[ ! -d "$GCC_SRC/.git" ]]; then
  git clone --depth 1 --branch "$GCC_REF" https://gcc.gnu.org/git/gcc.git "$GCC_SRC"
else
  log "Updating GCC"
  git -C "$GCC_SRC" fetch origin && git -C "$GCC_SRC" checkout "$GCC_REF"
fi

log "Downloading GCC prerequisites"
pushd "$GCC_SRC" >/dev/null
  ./contrib/download_prerequisites
popd >/dev/null

log "Building initial GCC (stage1)"
mkdir -p "$BUILD_GCC" && cd "$BUILD_GCC"
PATH="$PREFIX/bin:$PATH" \
  "$GCC_SRC/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --with-arch="$ARCH" \
    --with-abi="$ABI" \
    --enable-languages=c \
    --disable-nls \
    --disable-multilib \
    --without-headers \
    --disable-libssp
make -j"$JOBS" install-gcc

# 3) GDB
log "Cloning GDB ${GDB_VER}"
if [[ ! -d "$GDB_SRC" ]]; then
  wget -q --show-progress -O "$GDB_ARCHIVE" \
    "https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VER}.tar.gz"
  tar -xf "$GDB_ARCHIVE" -C "$SRC_DIR"
fi

log "Building GDB"
mkdir -p "$BUILD_GDB" && cd "$BUILD_GDB"
PATH="$PREFIX/bin:$PATH" \
  "$GDB_SRC/configure" --prefix="$PREFIX" --target="$TARGET"
make -j"$JOBS" install

# Verify
log "Verifying initial toolchain:"
"$PREFIX/bin/${TARGET}-gcc" --version | head -n1
"$PREFIX/bin/${TARGET}-ld"  --version | head -n1
"$PREFIX/bin/${TARGET}-gdb" --version | head -n1
ok "Initial toolchain is in '${PREFIX}'"