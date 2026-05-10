#!/bin/bash

# set the env variables
. ./test_env.sh
echo $WS_ROOT

# build the harness
cd unit-tests/harness
. ./build.sh

# run the tests
cd -
soft65c02_tester -i unit-tests/tests/fuji_init/test_init.txt
