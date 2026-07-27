#!/usr/bin/env python3
"""Retired b2 integration-test entry point.

The old b2 YAML runner was replaced by the Beebium scripted YAML runner in
``integration-tests/beebium/scripted/test_legacy_yaml_steps.py``. Keep this
small shim so accidental invocations fail clearly instead of running stale
coverage.
"""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "scripts/integration_test.py has been retired.\n"
        "\n"
        "Run the migrated Beebium YAML coverage instead:\n"
        "  ./integration-tests/beebium/run_pytest.sh "
        "scripted/test_legacy_yaml_steps.py -q\n"
        "\n"
        "For the full Beebium scripted gate:\n"
        "  ./integration-tests/beebium/run_product_tests.sh\n"
        "\n"
        "scripts/b2-http.py remains available for interactive b2 work.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
