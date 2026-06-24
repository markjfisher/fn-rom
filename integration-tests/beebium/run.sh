#!/usr/bin/env bash
# Convenience wrapper: same as run_pytest.sh (requires BEEBIUM_HOME + FUJINET_NIO_HOME).
exec "$(cd "$(dirname "$0")" && pwd)/run_pytest.sh" "$@"
