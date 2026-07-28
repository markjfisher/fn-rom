#!/bin/bash
# Run the soft65c02 unit tests against the product ROM.
#
# Usage: ./run_unit_tests.sh
#
# The harness consumes build/fujinet.rom.lbl.
set -euo pipefail

echo "==> unit tests against product ROM"

if ! command -v soft65c02_unit >/dev/null 2>&1; then
  echo "    soft65c02_unit not found on PATH -- skipping unit tests."
  echo "    (install the author's soft65c02 harness, e.g. cargo install --git ...)"
  exit 0
fi

# set the env variables
. ./test_env.sh

# build the ROM cleanly so stale objects cannot leak across machine/interface changes
make clean
make ssd

# create the include file for the harness to use ROM locations
cd unit-tests/harness
./create_rom_inc.sh

# run the tests
cd -

soft65c02_unit -i unit-tests/tests/fuji_init/test_fuji_init.yaml
soft65c02_unit -i unit-tests/tests/serial/test_scatter_checksum.yaml
soft65c02_unit -i unit-tests/tests/serial/test_slip_receive.yaml
soft65c02_unit -i unit-tests/tests/serial/test_slip_receive_to_payload.yaml
soft65c02_unit -i unit-tests/tests/network/test_bget_stream_not_ready.yaml
soft65c02_unit -i unit-tests/tests/network/test_bget_stream_no_probe_chunk.yaml
soft65c02_unit -i unit-tests/tests/network/test_reason_write_data_cursor.yaml
soft65c02_unit -i unit-tests/tests/parsing/test_parsing_defaults.yaml
soft65c02_unit -i unit-tests/tests/mapping/test_drive_mapping.yaml
soft65c02_unit -i unit-tests/tests/catalog/test_catalog_lookup.yaml
soft65c02_unit -i unit-tests/tests/cmd_run/test_cmd_run_library.yaml
soft65c02_unit -i unit-tests/tests/dir_params/test_dir_params.yaml
soft65c02_unit -i unit-tests/tests/param_helpers/test_param_helpers.yaml
soft65c02_unit -i unit-tests/tests/url_parsing/test_url_parsing.yaml
