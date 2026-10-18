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
  invisible to both repos. Instead of hand-editing and tracking a full `.config`,
  `build/.config` is *generated* by `configs/generate-config.sh` from the kernel's
  own stock `x86_64_defconfig` plus the small, documented options fragment at
  `configs/nf_tables-repro.fragment` — see [Build](#build).
- Kernel modifications are kept as patches in `patches/`, never committed in the submodule.

### Layout

| Path | Purpose |
|------|---------|
| `linux/` | Kernel submodule @ v6.6.14 |
| `poc/CVE-2024-1086/` | Exploit/reproducer submodule for CVE-2024-1086 |
| `poc/build-exploit.sh` | Builds the exploit, preflight-checking for `musl-gcc` |
| `configs/nf_tables-repro.fragment` | Minimal, documented kconfig fragment (source of truth) |
| `configs/generate-config.sh` | Generates `build/.config` from a stock defconfig + the fragment |
| `configs/verify-config.sh` | Checks a `.config` for the required options |
| `configs/detect-cc.sh` | Auto-selects a GCC version compatible with this kernel tree |
| `configs/linux-v6.6.14.config` | Legacy frozen full `.config` (fallback/reference only) |
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
against musl to avoid glibc ABI issues under QEMU/exotic rootfs). Install it
first if needed (Debian/Ubuntu/Mint: `sudo apt-get install -y musl-tools`;
Fedora: `sudo dnf install -y musl-gcc`; Arch: `sudo pacman -S musl`), then
build with:

```bash
poc/build-exploit.sh
# equivalent to:
#   cd poc/CVE-2024-1086 && make   # produces ./exploit
```

`poc/build-exploit.sh` preflight-checks for `musl-gcc` and prints the
install command above if it's missing, instead of failing deep inside the
build with a bare "No such file or directory".

See [Configuration requirements](#configuration-requirements) below for the
kconfig/sysctl requirements the kernel build must satisfy for this to work.

Copy `poc/CVE-2024-1086/exploit` into the initramfs/rootfs and run it as an
unprivileged user inside the VM; a successful run yields a root shell and
deliberately panics the kernel afterwards (left unmitigated upstream to make
exploitation attempts noisy). See `poc/CVE-2024-1086/src/config.h` for tunables
(PTE/skb spray amounts, scanned physical memory range, etc.) and the project's
[write-up](https://pwning.tech/nftables/) for background.

## Build

### Configuration requirements

- Architecture: x86-64.
- `CONFIG_NF_TABLES=y` — enables the nf_tables subsystem the PoC targets.
- `CONFIG_NETFILTER_NETLINK=y` — enables the netlink interface used by
  nf_tables (often referred to as NFNETLINK; there is no `CONFIG_NFNETLINK`
  Kconfig symbol).
- `CONFIG_USER_NS=y`, plus unprivileged user namespaces permitted at runtime
  (`sysctl kernel.unprivileged_userns_clone=1`, on distros that expose that
  knob) — lets the exploit run as an unprivileged user inside the VM.
- Avoid `CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y` on kernels newer than v6.4 — it
  defeats this exploit.

These requirements are captured, with rationale, in
`configs/nf_tables-repro.fragment` rather than relying on a hand-edited full
`.config`.

### Generating the config

From a clean clone, `configs/generate-config.sh` builds `build/.config` from
scratch: it starts from the kernel's own stock `x86_64_defconfig`, merges in
`configs/nf_tables-repro.fragment` with `scripts/kconfig/merge_config.sh`, runs
`olddefconfig` to resolve the rest, and then checks the result with
`configs/verify-config.sh`:

```bash
configs/generate-config.sh
# equivalent to:
#   make -C linux O=$PWD/build x86_64_defconfig
#   linux/scripts/kconfig/merge_config.sh -O build -m build/.config configs/nf_tables-repro.fragment
#   make -C linux O=$PWD/build olddefconfig
#   configs/verify-config.sh build/.config
```

`qemu/build-kernel.sh` calls this generator and then builds the kernel:

```bash
qemu/build-kernel.sh
```

`CONFIG_KASAN` is **not** enabled and `CONFIG_DEBUG_INFO` defaults to `NONE`
in the generated config — this matches a vanilla/distro-like build; enable
KASAN separately only if you want to confirm the underlying bug with
sanitizer instrumentation rather than exploit it (the two goals can conflict,
since KASAN changes allocator/reuse behavior the exploit relies on).

To tweak the config interactively instead:

```bash
make -C linux O=$PWD/build menuconfig
```

### Compiler compatibility

`configs/generate-config.sh` and `qemu/build-kernel.sh` both source
`configs/detect-cc.sh`, which auto-selects a compatible `gcc` (preferring
`gcc-13`/`gcc-12`/`gcc-11`/`gcc-10` over a bare `gcc`/`cc` that resolves to
GCC 15+). This v6.6 kernel tree fails to build with GCC 15+ because
`arch/x86/realmode/rm/Makefile` compiles 16-bit setup code with its own
`REALMODE_CFLAGS`, which (unlike the main build flags) never forces
`-std=gnu11` — a gap only fixed in later kernel trees. Since GCC 15 defaults
to `-std=gnu23`, where `bool`/`true`/`false` are reserved keywords, that code
fails to compile. Set `CC` in the environment to override the auto-detected
compiler.

### Legacy frozen config

`configs/linux-v6.6.14.config` is a previously hand-edited, full `.config`
kept for reference/fallback. Pass it explicitly to use it instead of the
generator:

```bash
qemu/build-kernel.sh configs/linux-v6.6.14.config
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
