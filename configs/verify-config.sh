#!/usr/bin/env bash
# Check that a kernel .config satisfies the requirements documented in
# README.md "Configuration requirements" for the nf_tables / CVE-2024-1086
# reproducer. Exits non-zero (with a summary) on any mismatch.
#
# Usage: configs/verify-config.sh [path-to-.config]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-$ROOT/build-6.2.16/.config}"

if [ ! -r "$CONFIG" ]; then
  echo "error: config file not found: $CONFIG" >&2
  exit 1
fi

# name=expected line (as it would literally appear in the .config)
declare -A REQUIRED=(
  [CONFIG_64BIT]="CONFIG_64BIT=y"
  [CONFIG_X86_64]="CONFIG_X86_64=y"
  [CONFIG_NF_TABLES]="CONFIG_NF_TABLES=y"
  [CONFIG_NF_TABLES_IPV4]="CONFIG_NF_TABLES_IPV4=y"
  [CONFIG_NETFILTER_NETLINK]="CONFIG_NETFILTER_NETLINK=y"
  [CONFIG_USER_NS]="CONFIG_USER_NS=y"
  [CONFIG_NET_NS]="CONFIG_NET_NS=y"
  [CONFIG_INIT_ON_ALLOC_DEFAULT_ON]="# CONFIG_INIT_ON_ALLOC_DEFAULT_ON is not set"
)

fail=0
for name in "${!REQUIRED[@]}"; do
  expected="${REQUIRED[$name]}"
  actual="$(grep -E "^(${name}=|# ${name} is not set)" "$CONFIG" || true)"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name -> expected '$expected', got '${actual:-<absent>}'" >&2
    fail=1
  else
    echo "OK:   $actual"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "One or more required kconfig options are not set as expected in $CONFIG" >&2
  exit 1
fi

cat <<'EOF'

All required options verified. Note the remaining host/runtime requirement
that this script cannot check: unprivileged user namespaces must be
permitted at runtime inside the VM (sysctl kernel.unprivileged_userns_clone=1,
where that sysctl exists).
EOF
