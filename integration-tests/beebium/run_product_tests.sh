#!/usr/bin/env bash
# Build the product ROM and run the Beebium scripted suite against it. Then run
# the command-from-disk tests: build FN-BOOT.ssd and prove transient utilities
# loaded from the library disk emit the expected FujiBus frames.
#
# Pass-through pytest args are forwarded to the product scripted run (e.g. -v,
# -k name). The FN-BOOT lane owns its focused test selection.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"   # repos/fn-rom

# Fail fast if Beebium test paths are not configured (see RUNNING_TESTS.md).
# shellcheck source=/dev/null
source "$here/check_test_env.sh"

if [ "${FN_BEEBIUM_NO_EVIDENCE:-}" = "1" ] ||
   [ "${FN_BEEBIUM_NO_EVIDENCE:-}" = "true" ] ||
   [ "${FN_BEEBIUM_NO_EVIDENCE:-}" = "yes" ]; then
  evidence_msg="disabled"
elif [ -z "${FN_BEEBIUM_EVIDENCE_ROOT:-}" ]; then
  export FN_BEEBIUM_EVIDENCE_ROOT="$root/test-evidence/beebium-$(date +%Y%m%d-%H%M%S)"
  evidence_msg="$FN_BEEBIUM_EVIDENCE_ROOT"
else
  evidence_msg="$FN_BEEBIUM_EVIDENCE_ROOT"
fi

echo "==> Beebium scripted coverage lanes:"
echo "    1. product = resident kernel + network + boot/config utilities on disk"
echo "    2. boot    = FN-BOOT transient-command lane (rebuilds FN-BOOT.ssd + OTHER.ssd)"
echo "==> Skips in the product lane are tests that need FN-BOOT mounted as a library."
echo "==> See integration-tests/beebium/RUNNING_TESTS.md for the coverage map."
echo "==> Screen evidence: $evidence_msg"

# A previous run killed mid-flight (e.g. by `timeout` or Ctrl-C) can leave a
# dangling PTY symlink pointing at a dead pts slave, which makes beebium's PTY
# setup intermittently fail later runs. Clear any stale one before we start.
pty="${FN_PTY:-/tmp/fujinet-pty-e2e}"
if [ -L "$pty" ] && [ ! -e "$pty" ]; then
  echo "==> removing stale PTY symlink: $pty"
  rm -f "$pty"
fi

echo "==> [product] build product ROM"
make -C "$root" clean all > /dev/null

echo "==> [product] beebium scripted"
( cd "$here" && echo "    expected skips: needs_boot_utils_setup" )
( cd "$here" && ./run_pytest.sh scripted/ -q "$@" )

echo "==> [boot] command-from-disk tests (build product ROM + FN-BOOT.ssd)"
"$root/scripts/run_fn_boot_test.sh"

echo "==> coverage summary: product + boot lanes passed"
