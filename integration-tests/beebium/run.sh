#!/usr/bin/env bash
# Convenience runner for the fn-rom <-> Beebium serial/PTY e2e tests.
#
# Builds nothing; assumes build/fujinet.rom and the beebium-server binary exist
# (see README.md). All pytest args are forwarded, e.g.:
#   ./run.sh -v
#   ./run.sh --fn-pty /tmp/my-fnpty -k fhost
set -euo pipefail
cd "$(dirname "$0")"
exec uv run pytest "$@"
