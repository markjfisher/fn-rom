#!/usr/bin/env bash
# Run Beebium integration tests. Requires BEEBIUM_HOME + FUJINET_NIO_HOME only.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "${BEEBIUM_HOME:-}" || -z "${FUJINET_NIO_HOME:-}" ]]; then
  echo "ERROR: set BEEBIUM_HOME and FUJINET_NIO_HOME (see docs/DEVELOPMENT.md)" >&2
  exit 1
fi

client="${BEEBIUM_HOME}/clients/python"
if [[ ! -f "${client}/pyproject.toml" ]]; then
  echo "ERROR: Beebium Python client not found at ${client}" >&2
  exit 1
fi

cd "$here"
# Use python -m pytest so the editable beebium client is on sys.path (.venv/bin/pytest
# alone does not pick up --with-editable).
exec uv run --with-editable "${client}" python -m pytest -p no:beebium "$@"
