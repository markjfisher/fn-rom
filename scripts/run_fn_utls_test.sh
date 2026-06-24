#!/usr/bin/env bash
# Build FN-UTLS.ssd (which builds the UTILITIES=disk ROM the binaries link
# against) and run the command-from-disk equivalence test against that exact ROM.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

"$root/scripts/build_fn_utls.sh"

# Build OTHER.ssd: a minimal DFS image that does NOT contain any utility, used by
# the *LIB library-fallback test (current drive holds this; the util resolves
# from the separate library drive). Regenerated each run so the test is
# self-contained.
other_src="$(mktemp -d)"
printf 'HELLO WORLD\r' > "$other_src/HELLO"
printf '$.HELLO 001900 001900\n' > "$other_src/HELLO.inf"
"$root/scripts/create_ssd.py" -i "$other_src" -o "$root/build/OTHER.ssd" -t OTHERDSK >/dev/null
rm -rf "$other_src"

cd "$root/integration-tests/beebium"
FN_UTLS_TEST=1 FN_ROM="$root/build/fujinet.rom" FN_PROFILE=net \
  ./run_pytest.sh scripted/test_command_from_disk.py -q -s
