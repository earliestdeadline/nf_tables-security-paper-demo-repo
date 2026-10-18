#!/usr/bin/env bash
# Generate a self-built kernel .config for the nf_tables / CVE-2024-1086
# reproducer from scratch: start from the kernel's own stock x86_64
# defconfig, layer the small documented fragment in
# configs/nf_tables-repro.fragment on top, and resolve the rest with
# olddefconfig. This avoids tracking/editing a frozen, hard-to-audit
# .config by hand.
#
# Usage: configs/generate-config.sh [build-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_DIR="$ROOT/linux"
BUILD_DIR="${1:-$ROOT/build-6.2.16}"
FRAGMENT="$ROOT/configs/nf_tables-repro.fragment"
if [[ "$BUILD_DIR" != /* ]]; then
  BUILD_DIR="$ROOT/$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

source "$ROOT/configs/detect-cc.sh"

# Stock baseline shipped by the kernel itself (arch/x86/configs/x86_64_defconfig), not hand-edited.
make -C "$LINUX_DIR" O="$BUILD_DIR" CC="$DETECTED_CC" x86_64_defconfig

# Merge the fragment on top; -m only merges (doesn't invoke make itself) so
# the subsequent olddefconfig below is the single, explicit resolution step.
( cd "$LINUX_DIR" && scripts/kconfig/merge_config.sh -O "$BUILD_DIR" -m "$BUILD_DIR/.config" "$FRAGMENT" )

# olddefconfig fills in any newly-reachable dependent symbols with their
# Kconfig defaults instead of prompting, while keeping everything the
# fragment set.
make -C "$LINUX_DIR" O="$BUILD_DIR" CC="$DETECTED_CC" olddefconfig

echo "Generated config: $BUILD_DIR/.config"
"$ROOT/configs/verify-config.sh" "$BUILD_DIR/.config"
