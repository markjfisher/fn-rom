#!/bin/bash

UT_BUILD_DIR=./build/unit-testing

# ASSUME WE ARE IN ROOT OF PROJECT
export SOFT65C02_BUILD_DIR=`realpath ${UT_BUILD_DIR}`
export WS_ROOT=`realpath .`
export UNIT_TEST_DIR=`realpath ./unit-tests`

mkdir -p ${UT_BUILD_DIR} > /dev/null 2>&1
