#!/usr/bin/env bash
# Build the pinned kernel out-of-tree.
#
# By default, generates build/.config from scratch via
# configs/generate-config.sh (stock x86_64_defconfig + the documented
# fragment in configs/nf_tables-repro.fragment). Pass an explicit
# config-file argument (e.g. the legacy tracked configs/linux-v6.6.14.config)
# to use a frozen .config instead.
#
# Usage: qemu/build-kernel.sh [config-file]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"

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
