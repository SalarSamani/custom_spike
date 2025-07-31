#!/usr/bin/env bash
# =============================================================================
# scripts/rebuild_toolchain_final.sh
#
#   Incremental rebuild of final Binutils, GCC (with Newlib) & GDB
#   - Assumes initial full build/configure has been done already
#   - Does NOT rerun configure; only make && make install on changed code
#
# Usage: rebuild_toolchain_final.sh [-t <target>] [-C <core-abi>] [-j <jobs>]
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults & Arg Parsing ───────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
JOBS=$(nproc)

while getopts ":t:C:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG"       ;;
    C) TARGET_CORE="$OPTARG"  ;;
    j) JOBS="$OPTARG"         ;;
    h) echo "Usage: $0 [-t <target>] [-C <core-abi>] [-j <jobs>]" >&2
       exit 1 ;;
    *) echo "Unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done

ARCH="${TARGET_CORE%%-*}"
ABI="${TARGET_CORE#*-}"

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${ROOT}/tools/toolchains/${TARGET_CORE}"
INIT_PREFIX="${BASE}/initial/install"
NEWLIB_PREFIX="${BASE}/newlib/install/${TARGET}"
SRC="${BASE}/final/source"
BUILD="${BASE}/final/build"
PREFIX="${BASE}/final/install"

# ─── Helpers ─────────────────────────────────────────────────────────────────
die() { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log() { echo -e "\e[1;34m➤\e[0m $*"; }
ok()  { echo -e "\e[1;32m✔\e[0m $*"; }

# Compute a single SHA1 over all files in a directory
compute_hash() {
  find "$1" -type f -print0 \
    | sort -z \
    | xargs -0 sha1sum \
    | sha1sum \
    | awk '{print $1}'
}

# ─── Sanity Checks ────────────────────────────────────────────────────────────
for cmd in make sha1sum; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required"
done

test -d "${SRC}/binutils-gdb" || die "No binutils source; run full build first"
test -d "${SRC}/gcc"         || die "No gcc source;    run full build first"

# ─── Figure Out What Changed ─────────────────────────────────────────────────
rebuild_binutils=false
rebuild_gcc=false

# Binutils
BIN_SRC="${SRC}/binutils-gdb"
BIN_BLD="${BUILD}/binutils"
BIN_STAMP="${BIN_BLD}/.src_hash"
cur_bin=$(compute_hash "$BIN_SRC")
if [[ ! -f "$BIN_STAMP" ]] || ! grep -qFx "$cur_bin" "$BIN_STAMP"; then
  rebuild_binutils=true
fi

# GCC
GCC_SRC="${SRC}/gcc"
GCC_BLD="${BUILD}/gcc"
GCC_STAMP="${GCC_BLD}/.src_hash"
cur_gcc=$(compute_hash "$GCC_SRC")
if [[ ! -f "$GCC_STAMP" ]] || ! grep -qFx "$cur_gcc" "$GCC_STAMP"; then
  rebuild_gcc=true
fi

# Nothing to do?
if ! $rebuild_binutils && ! $rebuild_gcc; then
  ok "No source changes detected; nothing to rebuild."
  exit 0
fi

# ─── Rebuild Binutils ─────────────────────────────────────────────────────────
if $rebuild_binutils; then
  log "Rebuilding Binutils (incremental)..."
  cd "$BIN_BLD"
  make -j"${JOBS}"
  make install
  echo "$cur_bin" > "$BIN_STAMP"
  ok "Binutils rebuilt."
  # force GCC rebuild if binutils changed
  rebuild_gcc=true
fi

# ─── Rebuild GCC ───────────────────────────────────────────────────────────────
if $rebuild_gcc; then
  log "Rebuilding GCC (incremental)..."
  cd "$GCC_BLD"
  make -j"${JOBS}"
  make install
  echo "$cur_gcc" > "$GCC_STAMP"
  ok "GCC rebuilt."
fi

ok "Incremental rebuild complete."
