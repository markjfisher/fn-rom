#!/usr/bin/env bash
# Build FN-UTLS.ssd (which builds the UTILITIES=disk ROM the binaries link
# against) and run the command-from-disk equivalence test against that exact ROM.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

"$root/scripts/build_fn_utls.sh"

cd "$root/integration-tests/beebium"
FN_UTLS_TEST=1 FN_ROM="$root/build/fujinet.rom" FN_PROFILE=net \
  uv run pytest scripted/test_command_from_disk.py -q -s
