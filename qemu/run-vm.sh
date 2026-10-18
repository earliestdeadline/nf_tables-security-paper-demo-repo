#!/usr/bin/env bash
# Boot the self-built kernel in an isolated QEMU VM (no network, serial console).
# Usage: qemu/run-vm.sh [initramfs.cpio.gz]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build-6.2.16}"
if [[ "$BUILD_DIR" != /* ]]; then
  BUILD_DIR="$ROOT/$BUILD_DIR"
fi
KERNEL="$BUILD_DIR/arch/x86/boot/bzImage"
INITRD="${1:-$BUILD_DIR/initramfs.cpio.gz}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "qemu-system-x86_64 not found; install QEMU before running the VM." >&2
  exit 1
fi

if [[ ! -f "$KERNEL" ]]; then
  echo "Kernel image not found: $KERNEL" >&2
  echo "Build it with: BUILD_DIR=$BUILD_DIR qemu/build-kernel.sh" >&2
  exit 1
fi

if [[ ! -f "$INITRD" ]]; then
  echo "Initramfs not found: $INITRD" >&2
  echo "Provide a cpio initramfs, for example: qemu/run-vm.sh /path/to/initramfs.cpio.gz" >&2
  exit 1
fi

exec qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "console=ttyS0 nokaslr panic=-1 oops=panic" \
  -nographic -no-reboot \
  -nic none
