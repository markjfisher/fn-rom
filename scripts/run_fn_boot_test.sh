#!/usr/bin/env bash
# Build FN-BOOT.ssd (which builds the product ROM the binaries link against) and
# run the command-from-disk tests against that exact ROM.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
machine="${BUILD_MACHINE:-BBC}"
case "$machine" in
  BBC) rom="$root/build/fujinet.rom" ;;
  MASTER) rom="$root/build/fujinet-master.rom" ;;
  *)
    echo "Invalid BUILD_MACHINE: $machine (expected BBC or MASTER)" >&2
    exit 1
    ;;
esac

"$root/scripts/build_fn_boot.sh"

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
FN_BOOT_TEST=1 FN_BEEBIUM_LANE=boot FN_ROM="$rom" \
  ./run_pytest.sh scripted/test_command_from_disk.py -q -s
