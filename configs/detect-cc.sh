# Sourced helper: picks a C compiler compatible with building this
# kernel tree. GCC >= 15 defaults to -std=gnu23, under which 'bool', 'true'
# and 'false' become reserved keywords. The main kernel build flags add
# -std=gnu11 to compensate, but arch/x86/realmode/rm/Makefile builds 16-bit
# setup code with its own REALMODE_CFLAGS that never does — a gap only
# fixed in later kernel trees — so it fails on GCC 15+ even though the rest
# of the build would succeed. Until the kernel is updated past that fix,
# prefer the newest available gcc below that threshold.
#
# Respects an existing $CC from the environment (assumed intentional).
# Usage: `source configs/detect-cc.sh` then use "$DETECTED_CC".
detect_cc() {
  if [ -n "${CC:-}" ]; then
    echo "$CC"
    return
  fi

  local candidates=(gcc-13 gcc-12 gcc-11 gcc-10 gcc cc)
  local c major
  for c in "${candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then
      major=$("$c" -dumpversion 2>/dev/null | cut -d. -f1)
      if [ -n "$major" ] && [ "$major" -lt 15 ]; then
        echo "$c"
        return
      fi
    fi
  done

  # Nothing compatible found; fall back to whatever 'gcc' resolves to and
  # let the build fail loudly rather than silently picking nothing.
  echo "gcc"
}

DETECTED_CC="$(detect_cc)"
