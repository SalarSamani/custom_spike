#!/usr/bin/env bash
# =============================================================================
# scripts/build_toolchain_newlib.sh
#
#   Stage 2: Build Newlib for TARGET_CORE using the initial toolchain
#   Sources in:     ./tools/toolchains/${TARGET_CORE}/newlib/source
#   Builds in:      ./tools/toolchains/${TARGET_CORE}/newlib/build
#   Installs into:  ./tools/toolchains/${TARGET_CORE}/newlib/install
#
# Usage: build_toolchain_newlib.sh [-t <target>] [-C <core-abi>] [-j <jobs>]
#
#   -t <target>      Cross-compile target triple (default: riscv32-unknown-elf)
#   -C <core-abi>    TARGET_CORE identifier (default: rv32imac-ilp32)
#   -j <jobs>        Parallel make jobs (default: number of processors)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Defaults ────────────────────────────────────────────────────────────────
TARGET="riscv32-unknown-elf"
TARGET_CORE="${TARGET_CORE:-rv32imac-ilp32}"
JOBS=$(nproc)
NEWLIB_URL="ftp://sourceware.org/pub/newlib/newlib-4.4.0.20231231.tar.gz"
NEWLIB_ARCHIVE="newlib-4.4.0.20231231.tar.gz"

# ─── Helpers ────────────────────────────────────────────────────────────────
die()  { echo -e "\e[1;31m✖ ERROR:\e[0m $*" >&2; exit 1; }
log()  { echo -e "\e[1;34m➤\e[0m $*"; }
ok()   { echo -e "\e[1;32m✔\e[0m $*"; }
usage(){ sed -n '1,20p' "$0"; exit 0; }

# ─── Arg Parsing ─────────────────────────────────────────────────────────────
while getopts ":t:C:j:h" opt; do
  case $opt in
    t) TARGET="$OPTARG"       ;;
    C) TARGET_CORE="$OPTARG"  ;;
    j) JOBS="$OPTARG"         ;;
    h) usage                   ;;
    *) die "Unknown option -$OPTARG" ;;
  esac
done

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${ROOT}/tools/toolchains/${TARGET_CORE}"
INIT_PREFIX="${BASE_DIR}/initial/install"
SRC_DIR="${BASE_DIR}/newlib/source"
BUILD_DIR="${BASE_DIR}/newlib/build"
PREFIX="${BASE_DIR}/newlib/install"

# ─── Prereq Checks ───────────────────────────────────────────────────────────
for cmd in wget tar make sed patch; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required"
done
# Ensure initial compiler exists
test -x "${INIT_PREFIX}/bin/${TARGET}-gcc" || die "Initial compiler not found in ${INIT_PREFIX}"
export PATH="${INIT_PREFIX}/bin:$PATH"
ok "Prerequisites OK (using compiler in ${INIT_PREFIX})"

# ─── Early Exit if Installed ─────────────────────────────────────────────────
if [[ -f "${PREFIX}/${TARGET}/lib/libc.a" && -f "${PREFIX}/${TARGET}/include/stdint.h" ]]; then
  ok "Newlib already present in ${PREFIX}"
  exit 0
fi

# ─── Prepare directories ─────────────────────────────────────────────────────
log "Preparing directories under ${BASE_DIR}/newlib"
mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

# ─── 1) Download & Extract Newlib ────────────────────────────────────────────
log "Fetching Newlib archive"
cd "${SRC_DIR}"
if [[ ! -d "${SRC_DIR}/${NEWLIB_ARCHIVE%.tar.gz}" ]]; then
  wget -c "${NEWLIB_URL}" -O "${NEWLIB_ARCHIVE}"
  log "Extracting Newlib"
  tar --strip-components=1 -xzf "${NEWLIB_ARCHIVE}"
else
  log "Newlib source already present, skipping"
fi

# ─── 2) Configure Newlib ─────────────────────────────────────────────────────
log "Configuring Newlib"
cd "${BUILD_DIR}"
"${SRC_DIR}/configure" \
  --prefix="${PREFIX}" \
  --target="${TARGET}"

# ─── 3) Build & Install Newlib ───────────────────────────────────────────────
log "Building Newlib"
make -j"${JOBS}"
log "Installing Newlib"
make install

# ─── Verification ────────────────────────────────────────────────────────────
log "Verifying Newlib installation:"
test -f "${PREFIX}/${TARGET}/include/stdint.h" || die "stdint.h missing"
test -f "${PREFIX}/${TARGET}/lib/libc.a"       || die "libc.a missing"
ok "Newlib is installed in '${PREFIX}/${TARGET}'"
