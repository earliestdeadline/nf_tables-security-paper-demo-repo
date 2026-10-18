#!/usr/bin/env bash
# Boot the self-built kernel in an isolated QEMU VM (no network, serial console).
# Usage: qemu/run-vm.sh [initramfs.cpio.gz]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL="$ROOT/build/arch/x86/boot/bzImage"
INITRD="${1:-$ROOT/build/initramfs.cpio.gz}"

exec qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2G \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "console=ttyS0 nokaslr panic=-1 oops=panic" \
  -nographic -no-reboot \
  -nic none
