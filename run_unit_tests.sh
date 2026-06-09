#!/bin/bash
# Run the soft65c02 unit tests against a chosen role-split build profile.
#
# Usage: ./run_unit_tests.sh [all|net|disk]   (default: all)
#   all   ALL build      (FEATURE_NET=1 UTILITIES=resident) -- everything resident
#   net   DISK+NET build (FEATURE_NET=1 UTILITIES=disk)
#   disk  DISK build     (FEATURE_NET=0 UTILITIES=disk)
#
# The harness consumes build/fujinet.rom.lbl, so the profile selects which ROM
# the tests are assembled against (see docs/ROM_ROLE_SPLIT_PLAN.md C.3/Phase 5).
set -euo pipefail

PROFILE="${1:-all}"
case "$PROFILE" in
  all)  MK_FLAGS=(FEATURE_NET=1 UTILITIES=resident) ;;
  net)  MK_FLAGS=(FEATURE_NET=1 UTILITIES=disk) ;;
  disk) MK_FLAGS=(FEATURE_NET=0 UTILITIES=disk) ;;
  *) echo "unknown profile '$PROFILE' (want: all|net|disk)" >&2; exit 2 ;;
esac

echo "==> unit tests against profile: $PROFILE (${MK_FLAGS[*]})"

if ! command -v soft65c02_unit >/dev/null 2>&1; then
  echo "    soft65c02_unit not found on PATH -- skipping unit tests."
  echo "    (install the author's soft65c02 harness, e.g. cargo install --git ...)"
  exit 0
fi

# set the env variables
. ./test_env.sh

# build the ROM for the selected profile (clean so no stale objects leak across profiles)
make clean
make "${MK_FLAGS[@]}" ssd

# create the include file for the harness to use ROM locations
cd unit-tests/harness
./create_rom_inc.sh

# run the tests
cd -

soft65c02_unit -i unit-tests/tests/fuji_init/test_fuji_init.yaml
soft65c02_unit -i unit-tests/tests/serial/test_scatter_checksum.yaml
soft65c02_unit -i unit-tests/tests/parsing/test_parsing_defaults.yaml
soft65c02_unit -i unit-tests/tests/mapping/test_drive_mapping.yaml
soft65c02_unit -i unit-tests/tests/catalog/test_catalog_lookup.yaml
soft65c02_unit -i unit-tests/tests/cmd_run/test_cmd_run_library.yaml
soft65c02_unit -i unit-tests/tests/dir_params/test_dir_params.yaml
soft65c02_unit -i unit-tests/tests/param_helpers/test_param_helpers.yaml
soft65c02_unit -i unit-tests/tests/url_parsing/test_url_parsing.yaml
