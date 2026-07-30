# Developer setup (fn-rom)

## Run tests

Build the ROM, set two paths, run the test gate:

```bash
make clean all

export BEEBIUM_HOME=/path/to/beebium
export FUJINET_NIO_HOME=/path/to/fujinet-nio

./run_tests.sh
```

That is all that is required for the Beebium integration matrix. There is no
`setup_tests.sh` or other venv sync step — `run_pytest.sh` attaches the Beebium
client from your checkout automatically.

Everything else is derived from those two roots:

| Derived | From |
|---------|------|
| `beebium-model-b` | `$BEEBIUM_HOME/build-release/...` or `$BEEBIUM_HOME/build/...` |
| MOS / BASIC ROMs | `$BEEBIUM_HOME/roms/` |
| `fujinet_tools` | `$FUJINET_NIO_HOME/py` |

Override any derived path with the usual env var (`BEEBIUM_SERVER`, `BEEBIUM_MOS`,
`FUJINET_TOOLS`, …) if autodetection does not match your layout.

## Prerequisites

- **cc65** (`ca65`, `cl65`, `ld65`) — build the ROM
- **beebium** built (`beebium-model-b` under your `BEEBIUM_HOME` checkout)
- **basictool**, **dfstool** — SSD helpers for some tests
- **soft65c02** — unit tests only ([unit-tests/README.md](../unit-tests/README.md))

Optional for `real/` interop tests: build fujinet-nio and set `FUJINET_BIN`.

## Common commands

```bash
./run_tests.sh --no-beebium          # builds + unit tests only
./run_unit_tests.sh                  # soft65c02 unit tests
./integration-tests/beebium/run_product_tests.sh   # Beebium scripted + FN-BOOT tests
cd integration-tests/beebium && ./run_pytest.sh scripted/ -q   # one-off pytest
./integration-tests/beebium/check_test_env.sh   # preflight (optional)
```

## Further reading

- [integration-tests/beebium/RUNNING_TESTS.md](../integration-tests/beebium/RUNNING_TESTS.md) — coverage map
- [docs/BOOT_DISK_PLAN.md](BOOT_DISK_PLAN.md) — product ROM and boot/config disk policy
