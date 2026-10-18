#!/usr/bin/env bash
# Build the pinned kernel out-of-tree.
#
# By default, generates the build directory's .config from scratch via
# configs/generate-config.sh (stock x86_64_defconfig + the documented
# fragment in configs/nf_tables-repro.fragment). Set BUILD_DIR to keep
# separate kernel versions' generated files apart. Pass an explicit config
# file only when intentionally using a frozen config.
#
# Usage: qemu/build-kernel.sh [config-file]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build-6.2.16}"
if [[ "$BUILD_DIR" != /* ]]; then
  BUILD_DIR="$ROOT/$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

source "$ROOT/configs/detect-cc.sh"

if [ "$#" -ge 1 ]; then
  CONFIG="$1"
  cp "$CONFIG" "$BUILD_DIR/.config"
  # olddefconfig fills in any new symbols with defaults instead of prompting,
  # while preserving everything already set in the supplied config.
  make -C "$ROOT/linux" O="$BUILD_DIR" CC="$DETECTED_CC" olddefconfig
  "$ROOT/configs/verify-config.sh" "$BUILD_DIR/.config"
else
  "$ROOT/configs/generate-config.sh" "$BUILD_DIR"
fi

make -C "$ROOT/linux" O="$BUILD_DIR" CC="$DETECTED_CC" -j"$(nproc)"

echo "Kernel built: $BUILD_DIR/arch/x86/boot/bzImage"
