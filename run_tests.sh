#!/usr/bin/env bash
# One-command role-split build x test matrix (docs/ROM_ROLE_SPLIT_PLAN.md Phase 5 / C.3).
#
# Builds all three shipped profiles, reports ROM sizes, runs the soft65c02 unit
# tests, then the beebium scripted matrix (which itself rebuilds each profile and
# runs the FN-UTLS command-from-disk equivalence test). Set BEEBIUM_HOME and
# FUJINET_NIO_HOME (see docs/DEVELOPMENT.md).
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
echo "# 1/4  Build all three profiles (BBC + Master)"
echo "############################################################"
make clean >/dev/null
make all-rom    # ALL: FEATURE_NET=1 UTILITIES=resident
make net        # DISK+NET: FEATURE_NET=1 UTILITIES=disk
make disk       # DISK: FEATURE_NET=0 UTILITIES=disk

echo
echo "############################################################"
echo "# 2/4  ROM sizes (rebuild ALL so build/*.map reflect it)"
echo "############################################################"
make clean >/dev/null
make all-machines >/dev/null
make sizes

echo
echo "############################################################"
echo "# 3/4  Unit tests (soft65c02) -- ALL profile"
echo "############################################################"
./run_unit_tests.sh all

if [ "$RUN_BEEBIUM" = "1" ]; then
  echo
  echo "############################################################"
  echo "# 4/4  Beebium scripted matrix (all / net / disk + FN-UTLS)"
  echo "############################################################"
  ./integration-tests/beebium/run_profile_tests.sh
else
  echo
  echo "(skipping beebium matrix: --no-beebium)"
fi

echo
echo "==> matrix complete"
