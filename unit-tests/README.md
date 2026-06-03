# Running unit tests

The soft65c02 tests are deprecated for now. There is too much setup involved in
getting data in the correct format. Moving to beebium tests in integration-tests folder.


```bash
export SOFT65C02_BUILD_DIR=$(realpath $PWD/build/unit-tests)
export UNIT_TEST_DIR=$(realpath $PWD/unit-tests)
export WS_ROOT=$(realpath .)
```