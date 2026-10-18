# nf_tables bug reproduction (Linux v6.6.14)

Workspace for reproducing an nf_tables bug on a vanilla, self-compiled
Linux **v6.6.14** kernel booted in an isolated QEMU VM.

## Repository configuration

- The kernel is a **git submodule** at `linux/`, pinned to tag `v6.6.14`
  (stable tree: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`).
  Only the pointer is tracked, not the kernel sources.
- `.gitmodules` sets `shallow = true`.
- Build output goes out-of-tree to `build/` (gitignored); the submodule stays clean.
- Kernel modifications are kept as patches in `patches/`, never committed in the submodule.

### Layout

| Path | Purpose |
|------|---------|
| `linux/` | Kernel submodule @ v6.6.14 |
| `configs/` | Tracked kernel `.config` files |
| `qemu/` | VM launch and rootfs/initramfs scripts |
| `poc/` | Reproducer code |
| `patches/` | Optional debug patches for the kernel |
| `notes/` | Progress log and findings |
| `build/` | Build output (ignored) |

## Getting started

```bash
git clone --recurse-submodules --shallow-submodules <this-repo>
# or, in an existing clone:
git submodule update --init --depth 1
git -C linux describe --tags   # expect v6.6.14
```

If the shallow checkout lacks the tag:

```bash
git -C linux fetch --depth 1 origin tag v6.6.14 && git -C linux checkout v6.6.14
```

## Build

```bash
make -C linux O=$PWD/build defconfig
# Enable (e.g. via `make -C linux O=$PWD/build menuconfig`), then save to configs/:
#   CONFIG_NF_TABLES=y CONFIG_NETFILTER=y CONFIG_USER_NS=y CONFIG_NET_NS=y
#   CONFIG_DEBUG_INFO_DWARF5=y CONFIG_KASAN=y CONFIG_KALLSYMS=y
#   CONFIG_SERIAL_8250_CONSOLE=y CONFIG_BLK_DEV_INITRD=y
make -C linux O=$PWD/build -j"$(nproc)"
```

## Run

Provide an initramfs at `build/initramfs.cpio.gz` (e.g. busybox-based), then:

```bash
qemu/run-vm.sh
```

The VM has no network (`-nic none`), serial console only, and panics on oops.
Use `Ctrl-A X` to exit QEMU.

## Notes

Record progress in `notes/`.
