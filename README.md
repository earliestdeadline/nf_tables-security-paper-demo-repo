# nf_tables bug reproduction (Linux v6.6.14)

Workspace for reproducing an nf_tables bug on a vanilla, self-compiled
Linux **v6.6.14** kernel booted in an isolated QEMU VM.

## Repository configuration

- The kernel is a **git submodule** at `linux/`, pinned to tag `v6.6.14`
  (stable tree: `https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`).
  Only the pointer is tracked, not the kernel sources.
- The reproducer is a **git submodule** at `poc/CVE-2024-1086`, pointing to
  [Notselwyn/CVE-2024-1086](https://github.com/Notselwyn/CVE-2024-1086)
  — a universal local-privilege-escalation PoC for the nf_tables `nft_set_elem`
  double-free/UAF ([CVE-2024-1086](https://nvd.nist.gov/vuln/detail/CVE-2024-1086)),
  affecting kernels v5.14–v6.6 (patched in v6.6.15, among others). v6.6.14 is
  the last vulnerable point release on that branch, which is why it was chosen here.
- `.gitmodules` sets `shallow = true` for both submodules.
- Build output, **including `.config`**, goes out-of-tree to `build/` (gitignored); the
  submodules stay clean. A submodule can only be pinned as a whole (one commit SHA) —
  git has no way to track individual files inside it from the parent repo — so the
  kernel's own `.gitignore` would otherwise swallow `.config` as an untracked file
  invisible to both repos. Instead, the config is tracked in `configs/` here and
  copied into `build/.config` before building.
- Kernel modifications are kept as patches in `patches/`, never committed in the submodule.

### Layout

| Path | Purpose |
|------|---------|
| `linux/` | Kernel submodule @ v6.6.14 |
| `poc/CVE-2024-1086/` | Exploit/reproducer submodule for CVE-2024-1086 |
| `configs/` | Tracked kernel `.config` files (e.g. `linux-v6.6.14.config`) |
| `qemu/` | VM launch and rootfs/initramfs scripts |
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

## Reproducer (CVE-2024-1086)

`poc/CVE-2024-1086` requires `musl-gcc` to build (the Makefile links statically
against musl to avoid glibc ABI issues under QEMU/exotic rootfs):

```bash
cd poc/CVE-2024-1086
make        # produces ./exploit
```

Key requirements enforced inside the VM's kconfig/sysctl (should already hold
for a vanilla v6.6.14 build enabling the options below):
- `CONFIG_USER_NS=y` and unprivileged user namespaces allowed
  (`sysctl kernel.unprivileged_userns_clone=1`)
- `CONFIG_NF_TABLES=y`
- Avoid `CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y` — it defeats this exploit on v6.4+.

Copy `poc/CVE-2024-1086/exploit` into the initramfs/rootfs and run it as an
unprivileged user inside the VM; a successful run yields a root shell and
deliberately panics the kernel afterwards (left unmitigated upstream to make
exploitation attempts noisy). See `poc/CVE-2024-1086/src/config.h` for tunables
(PTE/skb spray amounts, scanned physical memory range, etc.) and the project's
[write-up](https://pwning.tech/nftables/) for background.

## Build

The tracked config at `configs/linux-v6.6.14.config` already enables what the
CVE-2024-1086 reproducer needs: `CONFIG_NF_TABLES=y`, `CONFIG_USER_NS=y`,
`CONFIG_NET_NS=y`, `CONFIG_KALLSYMS=y`, `CONFIG_SERIAL_8250_CONSOLE=y`,
`CONFIG_BLK_DEV_INITRD=y`, and leaves `CONFIG_INIT_ON_ALLOC_DEFAULT_ON=n`
(enabling it defeats the exploit on v6.4+). `CONFIG_KASAN` is **not** enabled
and `CONFIG_DEBUG_INFO` is set to `NONE` — this matches a vanilla/distro-like
build; enable KASAN separately only if you want to confirm the underlying bug
with sanitizer instrumentation rather than exploit it (the two goals can
conflict, since KASAN changes allocator/reuse behavior the exploit relies on).

```bash
qemu/build-kernel.sh
# equivalent to:
#   mkdir -p build && cp configs/linux-v6.6.14.config build/.config
#   make -C linux O=$PWD/build olddefconfig
#   make -C linux O=$PWD/build -j"$(nproc)"
```

To tweak the config, edit it out-of-tree and resync it back into the repo:

```bash
make -C linux O=$PWD/build menuconfig
cp build/.config configs/linux-v6.6.14.config   # persist your changes
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
