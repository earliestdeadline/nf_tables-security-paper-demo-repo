#!/usr/bin/env bash
# Build the pinned kernel out-of-tree using the tracked .config in configs/.
# Usage: qemu/build-kernel.sh [config-file]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-$ROOT/configs/linux-v6.6.14.config}"
BUILD_DIR="$ROOT/build"

mkdir -p "$BUILD_DIR"
cp "$CONFIG" "$BUILD_DIR/.config"

# olddefconfig fills in any new symbols with defaults instead of prompting,
# while preserving everything already set in the tracked config.
make -C "$ROOT/linux" O="$BUILD_DIR" olddefconfig
make -C "$ROOT/linux" O="$BUILD_DIR" -j"$(nproc)"

echo "Kernel built: $BUILD_DIR/arch/x86/boot/bzImage"
echo "To update the tracked config after menuconfig changes, run:"
echo "  cp \"$BUILD_DIR/.config\" \"$CONFIG\""
