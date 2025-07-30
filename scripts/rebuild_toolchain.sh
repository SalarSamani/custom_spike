#!/usr/bin/env bash
# =============================================================================
# scripts/rebuild_toolchain.sh
#
#   Incrementally rebuild only the parts of the toolchain under:
#     tools/toolchains/<TARGET_CORE>/{source,build,install}
#
# Usage:
#   TARGET_CORE=rv32imac-ilp32 ./scripts/rebuild_toolchain.sh
#   TARGET_CORE=rv64gc-lp64   ./scripts/rebuild_toolchain.sh -d 12.1
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults & Arg Parsing ───────────────────────────────────────────────────
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
GDB_VER="${GDB_VER:-13.2}"
JOBS=$(nproc)

usage() {
  echo "Usage: TARGET_CORE=<core-abi> GDB_VER=<ver> $0 [-C <core-abi>] [-d <gdb-ver>] [-j <jobs>]"
  exit 0
}

while getopts ":C:d:j:h" opt; do
  case $opt in
    C) TARGET_CORE="$OPTARG" ;;
    d) GDB_VER="$OPTARG"     ;;
    j) JOBS="$OPTARG"        ;;
    h) usage                 ;;
    *) usage                 ;;
  esac
done

# ─── Derive target triple, ARCH/ABI ─────────────────────────────────────────
case "$TARGET_CORE" in
  rv32*) TARGET="riscv32-unknown-elf" ;;
  rv64*) TARGET="riscv64-unknown-elf" ;;
  *) echo "Unknown TARGET_CORE: $TARGET_CORE"; exit 1 ;;
esac

ARCH="${TARGET_CORE%%-*}"
ABI="${TARGET_CORE#*-}"

# ─── Paths & Stamps ───────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${ROOT}/tools/toolchains/${TARGET_CORE}"
SRC_DIR="${BASE_DIR}/source"
BUILD_DIR="${BASE_DIR}/build"
PREFIX="${BASE_DIR}/install"

STAMP_BINUTILS="${BUILD_DIR}/binutils/.stamp"
STAMP_GCC="${BUILD_DIR}/gcc/.stamp"
STAMP_GDB="${BUILD_DIR}/gdb/.stamp"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }

# ─── 0) Prereqs ───────────────────────────────────────────────────────────────
for cmd in make gcc patch; do
  command -v "$cmd" >/dev/null || die "Missing prerequisite: $cmd"
done
ok "Prerequisites OK"

# ─── 1) Rebuild Binutils if changed ──────────────────────────────────────────
BINUTILS_SRC="${SRC_DIR}/binutils-gdb"
if [[ ! -d "$BINUTILS_SRC/.git" ]]; then
  die "binutils source not found in $BINUTILS_SRC"
fi
curr=$(git -C "$BINUTILS_SRC" rev-parse HEAD)
prev=$(<"$STAMP_BINUTILS" 2>/dev/null || echo "")
if [[ "$curr" == "$prev" ]]; then
  ok "binutils: no changes"
else
  log "Rebuilding binutils (was $prev → $curr)"
  mkdir -p "$BUILD_DIR/binutils"
  cd "$BUILD_DIR/binutils"
  "$BINUTILS_SRC/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --disable-nls \
    --disable-multilib
  make -j"$JOBS" && make install
  echo "$curr" > "$STAMP_BINUTILS"
  ok "binutils rebuilt"
fi

# ─── 2) Rebuild GCC if changed ────────────────────────────────────────────────
GCC_SRC="${SRC_DIR}/gcc"
if [[ ! -d "$GCC_SRC/.git" ]]; then
  die "gcc source not found in $GCC_SRC"
fi
curr=$(git -C "$GCC_SRC" rev-parse HEAD)
prev=$(<"$STAMP_GCC" 2>/dev/null || echo "")
if [[ "$curr" == "$prev" ]]; then
  ok "gcc: no changes"
else
  log "Rebuilding gcc (was $prev → $curr)"
  mkdir -p "$BUILD_DIR/gcc"
  cd "$BUILD_DIR/gcc"
  # Ensure prerequisites are in place
  "$GCC_SRC/contrib/download_prerequisites"
  "$GCC_SRC/configure" \
    --prefix="$PREFIX" \
    --target="$TARGET" \
    --with-arch="$ARCH" \
    --with-abi="$ABI" \
    --enable-languages=c \
    --disable-nls \
    --disable-multilib \
    --with-newlib \
    --without-headers
  make all-gcc -j"$JOBS" && make install-gcc
  echo "$curr" > "$STAMP_GCC"
  ok "gcc rebuilt"
fi

# ─── 3) Rebuild GDB if changed ────────────────────────────────────────────────
GDB_SRC="${SRC_DIR}/gdb-${GDB_VER}"
if [[ ! -d "$GDB_SRC" ]]; then
  die "gdb source not found in $GDB_SRC"
fi
# Rebuild if any source file is newer than stamp
if [[ -f "$STAMP_GDB" && -z $(find "$GDB_SRC" -type f -newer "$STAMP_GDB" -print -quit) ]]; then
  ok "gdb: no changes"
else
  log "Rebuilding gdb"
  mkdir -p "$BUILD_DIR/gdb"
  cd "$BUILD_DIR/gdb"
  "$GDB_SRC/configure" --prefix="$PREFIX" --target="$TARGET"
  make -j"$JOBS" && make install
  touch "$STAMP_GDB"
  ok "gdb rebuilt"
fi

ok "Rebuild complete for ${TARGET_CORE} in ${PREFIX}"
