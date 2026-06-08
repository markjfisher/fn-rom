#!/usr/bin/env bash
# Build each role-split profile's ROM and run the feature-appropriate beebium
# scripted subset against it (see docs/ROM_ROLE_SPLIT_PLAN.md C.3). All builds
# write build/fujinet.rom, so this runs them sequentially.
#
#   all  profile (ALL):      network device + utilities resident; full suite.
#   net  profile (DISK+NET): network device, utils on disk; full suite.
#   disk profile (DISK):     no network device; needs_net tests skip, disk_only run.
#
# Then the command-from-disk equivalence test (Appendix C.4 #3): build the
# UTILITIES=disk ROM + FN-UTLS.ssd and prove a transient utility loaded from the
# library disk emits the same FujiBus frames as the resident command.
#
# Pass-through pytest args are forwarded to each scripted run (e.g. -v, -k name).
set -euo pipefail

LOG_FILE=/tmp/profile_tests.log

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"   # repos/fn-rom

echo "here: $here, root: $root, LOG_FILE=$LOG_FILE"

# A previous run killed mid-flight (e.g. by `timeout` or Ctrl-C) can leave a
# dangling PTY symlink pointing at a dead pts slave, which makes beebium's PTY
# setup intermittently fail later runs. Clear any stale one before we start.
pty="${FN_PTY:-/tmp/fujinet-pty-e2e}"
if [ -L "$pty" ] && [ ! -e "$pty" ]; then
  echo "==> removing stale PTY symlink: $pty"
  rm -f "$pty"
fi

echo "==> [all] build ALL ROM (FEATURE_NET=1 UTILITIES=resident)"
make -C "$root" clean all-rom | tee ${LOG_FILE}

echo "==> [all] beebium scripted (FN_PROFILE=all, utils resident)"
( cd "$here" && FN_PROFILE=all uv run pytest scripted/ -q "$@" )

echo "==> [net] build DISK+NET ROM (FEATURE_NET=1 UTILITIES=disk)"
make -C "$root" clean net | tee -a ${LOG_FILE}

echo "==> [net] beebium scripted (FN_PROFILE=net)"
( cd "$here" && FN_PROFILE=net uv run pytest scripted/ -q "$@" )

echo "==> [disk] build DISK ROM (FEATURE_NET=0 UTILITIES=disk)"
make -C "$root" clean disk | tee -a ${LOG_FILE}

echo "==> [disk] beebium scripted (FN_PROFILE=disk)"
( cd "$here" && FN_PROFILE=disk uv run pytest scripted/ -q "$@" )

echo "==> [utls] command-from-disk equivalence (build UTILITIES=disk ROM + FN-UTLS.ssd)"
"$root/scripts/run_fn_utls_test.sh"

echo "==> profile matrix OK"
