#!/bin/bash

mkdir -p ./unit-tests/harness/build > /dev/null 2>&1

# ASSUME WE ARE IN ROOT OF PROJECT
export SOFT65C02_BUILD_DIR=`realpath ./unit-tests/harness/build`
export WS_ROOT=`realpath .`
export UNIT_TEST_DIR=`realpath ./unit-tests`
