#!/usr/bin/env bash
# Build each role-split profile's ROM and run the feature-appropriate beebium
# scripted subset against it (see docs/ROM_ROLE_SPLIT_PLAN.md C.3). Both builds
# write build/fujinet.rom, so this runs them sequentially.
#
#   net  profile: full suite; disk_only negative tests skip.
#   disk profile: network (needs_net) tests skip; disk-side + negative tests run.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"   # repos/fn-rom

echo "==> [net] build DISK+NET ROM"
make -C "$root" all >/dev/null

echo "==> [net] beebium scripted (FN_PROFILE=net)"
( cd "$here" && FN_PROFILE=net uv run pytest scripted/ -q )

echo "==> [disk] build DISK ROM (FEATURE_NET=0)"
make -C "$root" FEATURE_NET=0 all >/dev/null

echo "==> [disk] beebium scripted (FN_PROFILE=disk)"
( cd "$here" && FN_PROFILE=disk uv run pytest scripted/ -q )

echo "==> profile matrix OK"
