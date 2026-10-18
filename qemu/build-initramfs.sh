#!/usr/bin/env bash
# Assemble a minimal BusyBox initramfs containing the CVE-2024-1086 PoC.
# Usage: qemu/build-initramfs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build-6.2.16}"
if [[ "$BUILD_DIR" != /* ]]; then
  BUILD_DIR="$ROOT/$BUILD_DIR"
fi
POC="$ROOT/poc/CVE-2024-1086/exploit"
BUSYBOX="${BUSYBOX:-$(command -v busybox || true)}"

if [[ -z "$BUSYBOX" || ! -x "$BUSYBOX" ]]; then
  echo "BusyBox not found; install a statically linked BusyBox or set BUSYBOX=/path/to/busybox." >&2
  exit 1
fi

if [[ ! -f "$POC" ]]; then
  echo "Exploit binary not found: $POC" >&2
  echo "Build it first with: poc/build-exploit.sh" >&2
  exit 1
fi

if ! command -v cpio >/dev/null 2>&1; then
  echo "cpio not found; install cpio before building the initramfs." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
ROOTFS="$(mktemp -d "$BUILD_DIR/initramfs.XXXXXX")"
OUTPUT_TMP="$(mktemp "$BUILD_DIR/initramfs.cpio.gz.XXXXXX")"
cleanup() {
  rm -rf "$ROOTFS"
  rm -f "$OUTPUT_TMP"
}
trap cleanup EXIT

mkdir -p "$ROOTFS"/{bin,dev,etc,home/nobody,proc,root,sbin,sys,tmp,usr/bin}
cp "$BUSYBOX" "$ROOTFS/bin/busybox"
ln -s busybox "$ROOTFS/bin/sh"
for applet in chmod chown cttyhack mkdir mknod mount setsid su; do
  ln -s busybox "$ROOTFS/bin/$applet"
done
cp "$ROOT/qemu/init" "$ROOTFS/init"
chmod 0755 "$ROOTFS/init" "$ROOTFS/bin/busybox"
cp "$POC" "$ROOTFS/home/nobody/exploit"
chmod 0755 "$ROOTFS/home/nobody/exploit"
cat > "$ROOTFS/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/home/nobody:/bin/sh
EOF
cat > "$ROOTFS/etc/group" <<'EOF'
root:x:0:
nobody:x:65534:
EOF
chmod 1777 "$ROOTFS/tmp"
chmod 0755 "$ROOTFS"

(
  cd "$ROOTFS"
  find . -print0 | LC_ALL=C sort -z |
    cpio --null -o --format=newc --owner=0:0 2>/dev/null |
    gzip -n -9 > "$OUTPUT_TMP"
)
mv -f "$OUTPUT_TMP" "$BUILD_DIR/initramfs.cpio.gz"
echo "Initramfs built: $BUILD_DIR/initramfs.cpio.gz"
