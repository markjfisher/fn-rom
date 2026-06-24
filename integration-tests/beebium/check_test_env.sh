#!/usr/bin/env bash
# Preflight: required repo roots + pytest collect smoke (optional).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

require_var() {
  if [[ -z "${!1:-}" ]]; then
    echo "ERROR: $1 must be set (see docs/DEVELOPMENT.md)" >&2
    exit 1
  fi
}

require_var BEEBIUM_HOME
require_var FUJINET_NIO_HOME

[[ -d "${BEEBIUM_HOME}" ]] || { echo "ERROR: BEEBIUM_HOME not a directory: ${BEEBIUM_HOME}" >&2; exit 1; }
[[ -d "${FUJINET_NIO_HOME}" ]] || { echo "ERROR: FUJINET_NIO_HOME not a directory: ${FUJINET_NIO_HOME}" >&2; exit 1; }

if [[ "${CHECK_TEST_ENV_SMOKE:-1}" == "1" ]]; then
  "${here}/run_pytest.sh" --collect-only -q >/dev/null
fi

echo "==> Beebium test environment OK"
