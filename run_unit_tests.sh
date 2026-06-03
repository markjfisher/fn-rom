#!/bin/bash

# set the env variables
. ./test_env.sh

# build the ROM
make clean ssd

# create the include file for the harness to use ROM locations
cd unit-tests/harness
./create_rom_inc.sh

# run the tests
cd -

# soft65c02_unit -i unit-tests/tests/fuji_init/test_fuji_init.yaml
soft65c02_unit -i unit-tests/tests/serial/test_scatter_checksum.yaml
# soft65c02_unit -v -i unit-tests/tests/commands/fls/test_fls.yaml
# soft65c02_unit -v -i unit-tests/tests/commands/fls/test_fls_long.yaml
# soft65c02_unit -i unit-tests/tests/commands/copy/test_copy.yaml
