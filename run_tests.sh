#!/usr/bin/env bash
# One-command product build x test runner.
#
# Builds the product ROMs, reports ROM sizes, runs the soft65c02 unit tests, then
# the Beebium scripted suite plus the FN-BOOT command-from-disk tests. Set
# BEEBIUM_HOME and FUJINET_NIO_HOME (see docs/DEVELOPMENT.md).
#
# Usage:
#   ./run_tests.sh            # full matrix
#   ./run_tests.sh --no-beebium   # builds + sizes + unit tests only
set -euo pipefail
cd "$(dirname "$0")"

RUN_BEEBIUM=1
for arg in "$@"; do
  case "$arg" in
    --no-beebium) RUN_BEEBIUM=0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

echo "############################################################"
echo "# 1/4  Build product ROMs (BBC + Master)"
echo "############################################################"
make clean >/dev/null
make all-machines

echo
echo "############################################################"
echo "# 2/4  ROM sizes"
echo "############################################################"
make sizes

echo
echo "############################################################"
echo "# 3/4  Unit tests (soft65c02)"
echo "############################################################"
./run_unit_tests.sh

if [ "$RUN_BEEBIUM" = "1" ]; then
  echo
  echo "############################################################"
  echo "# 4/4  Beebium scripted tests + FN-BOOT"
  echo "############################################################"
  ./integration-tests/beebium/run_product_tests.sh
else
  echo
  echo "(skipping beebium matrix: --no-beebium)"
fi

echo
echo "==> matrix complete"
