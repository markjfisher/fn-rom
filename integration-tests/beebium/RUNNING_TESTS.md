# Running The Beebium Tests

This guide is the short, practical companion to `README.md`.

Use this file when you want to know:

- what command to run
- which skips are expected
- when coverage is complete

**Setup:** export `BEEBIUM_HOME` and `FUJINET_NIO_HOME`, then run tests. See
[docs/DEVELOPMENT.md](../../docs/DEVELOPMENT.md). Use `./run_pytest.sh` (not bare
`uv run pytest`).

## Short Answer

If you want confidence that the Beebium scripted coverage is complete, run:

```bash
./integration-tests/beebium/run_product_tests.sh
```

If you want the repository's normal full local gate, run:

```bash
./run_tests.sh
```

Coverage is complete when both Beebium lanes pass:

1. product ROM scripted tests
2. `FN-BOOT` command-from-disk lane

Skips in the product lane are expected only for tests that need `FN-BOOT.ssd`
mounted as the library. Those are covered by the command-from-disk lane.

Each Beebium test that launches an emulator writes screen evidence under
`test-evidence/beebium-YYYYMMDD-HHMMSS/` by default. A product-lane run
shares one evidence folder across all lanes. This directory is outside `build/`
so product rebuilds and `make clean` do not delete evidence from earlier lanes.

## What To Run

### 1. Full repo gate

Runs builds, sizes, unit tests, then the Beebium scripted matrix.

```bash
./run_tests.sh
```

Skip Beebium if your emulator environment is not available:

```bash
./run_tests.sh --no-beebium
```

### 2. Beebium scripted tests only

This is the main command for the Beebium scripted gate.

```bash
./integration-tests/beebium/run_product_tests.sh
```

This runs two lanes in sequence:

1. `product`: build the product ROM and run the normal scripted suite
2. `boot`: rebuild transient utility artifacts and run `test_command_from_disk.py`

The second lane is important. It creates `build/FN-BOOT.ssd` and
`build/OTHER.ssd` and proves the transient-command-on-disk behavior.

The script prints the evidence directory near the start of the run.

### 3. Product scripted tests only

Useful while iterating on resident ROM behavior:

```bash
make all
cd integration-tests/beebium
./run_pytest.sh scripted/ -q
```

### 4. Transient command / FN-BOOT lane only

Use this when changing disk-loaded utility behavior such as `*FLS`, `*FDRIVE`,
`*FCD`, library-drive fallback, or argument passing.

```bash
./scripts/run_fn_boot_test.sh
```

This script:

1. builds the product ROM
2. rebuilds `build/FN-BOOT.ssd`
3. rebuilds `build/OTHER.ssd`
4. runs `integration-tests/beebium/scripted/test_command_from_disk.py`

If you need just one command-from-disk test after the assets exist:

```bash
cd integration-tests/beebium
FN_BOOT_TEST=1 FN_ROM=../../build/fujinet.rom \
  ./run_pytest.sh scripted/test_command_from_disk.py -q -k library_drive
```

### 5. Migrated legacy YAML suites

Some of the older `integration-tests/steps/*.yaml` b2 suites are run through
Beebium by `scripted/test_legacy_yaml_steps.py`.

These tests create fresh SSD images in pytest temporary directories, mount them
through the scripted Fuji disk responder, and then replay the YAML `paste` and
`screen.expect` steps. Disk writes are handled in memory by the responder, so
tests such as OSFILE do not leave locked or modified files behind for the next
run.

The open/network suites build `openbas.ssd` from a temporary copy of the BASIC
sources with service URLs templated to deterministic loopback-style values.
Those URLs are then served by the scripted NetworkDevice responder; no b2
emulator, real fujinet-nio process, TNFS share, httpbin container, HTTP file
server, or TCP echo service is required for the scripted matrix.

Supported today:

- `01_osfile.yaml`
- `02_osargs.yaml`
- `03_open.yaml`
- `04_ctests.yaml` is marked `needs_boot_utils_setup`; utility coverage runs in
  the FN-BOOT command-from-disk lane
- `05_long_str.yaml`
- `06_json.yaml`

The runner deliberately supports only the YAML features used by those migrated
suites: top-level `disk`/`paste`, step `paste`, step `delay_seconds`, and screen
checks with `contains` or `regex`.

The old `scripts/integration_test.py` b2 runner has been retired and now exits
with a pointer to this Beebium path. `scripts/b2-http.py` remains available for
interactive b2 work.

## Screen Evidence

For every Beebium test that starts an emulator, the fixture captures numbered
screen/frame checkpoints when a screen assertion succeeds or times out, plus a
final teardown frame. This makes the progress of longer tests visible after the
run.

- `screen_000.txt`, `screen_001.txt`, ...: scroll-corrected MODE 7 text via `beebium.client.screen.dump_screen`
- `frame_000.png`, `frame_001.png`, ...: raw video frames saved as PNG
- `frame_000.ppm`, `frame_001.ppm`, ...: fallback raw video frames if PNG saving fails
- `captures.tsv`: ordered capture labels and frame details
- `metadata.txt`: test node id, lane label, status, and capture time

The default path is:

```bash
test-evidence/beebium-YYYYMMDD-HHMMSS/<lane>/<status>/<test>/
```

While a test is running, its directory lives under
`test-evidence/beebium-YYYYMMDD-HHMMSS/<lane>/running/<test>/`. At teardown it
is moved to `passed`, `failed`, or the pytest outcome reported for that test.

Override the root when you want a known location:

```bash
FN_BEEBIUM_EVIDENCE_ROOT=test-evidence/my-run \
  ./integration-tests/beebium/run_product_tests.sh
```

Disable evidence capture for a run:

```bash
FN_BEEBIUM_NO_EVIDENCE=1 ./integration-tests/beebium/run_product_tests.sh
```

or pass `--no-screen-evidence` through `run_pytest.sh` for direct pytest runs.

## Why The Skips Are Expected

The normal scripted suite runs without `FN-BOOT.ssd` mounted as the library.
Tests that exercise disk-loaded utilities are skipped there and covered in the
FN-BOOT lane.

### Marker meanings

| Marker | Runs on | Skips on | Why |
|--------|---------|----------|-----|
| `needs_net` | product lane | never by product build | the network device is always resident |
| `needs_boot_utils_setup` | FN-BOOT lane | product lane | utility requires the boot/config disk mounted as library |

### Meaning of each lane

| Lane | What it proves | Expected skips |
|------|----------------|----------------|
| `product` | resident kernel, disk, network paths, normal scripted transport coverage | `needs_boot_utils_setup` |
| `boot` | transient command loading from `FN-BOOT.ssd`, including library fallback and argument passing | none expected |

So the presence of skips does not mean coverage is missing. It means coverage is
split across lanes.

## How To Know Coverage Is Complete

For the Beebium scripted layer, coverage is complete when these both pass:

1. product scripted lane
2. `boot` command-from-disk lane

That is exactly what `run_product_tests.sh` is intended to represent.

The product lane covers resident ROM behavior. The `boot` lane covers transient
utilities that are deliberately absent from the ROM.

If only the product lane runs, coverage is not complete for transient utilities.
If only the `boot` lane runs, coverage is not complete for resident ROM behavior.

## Recommended Workflows

### Fast local iteration on one area

Network feature change:

```bash
make all
cd integration-tests/beebium
./run_pytest.sh scripted/test_network_device.py -q
```

Transient utility change:

```bash
./scripts/run_fn_boot_test.sh -k fls
```

### Before committing

Run the Beebium scripted gate:

```bash
./integration-tests/beebium/run_product_tests.sh
```

### Before merging / when you want the normal full gate

```bash
./run_tests.sh
```

## Optional Real-Firmware Interop

The commands above are for the deterministic scripted Beebium suite.

If you also want the opt-in real-firmware interop layer:

```bash
cd integration-tests/beebium
./run_pytest.sh real/ -q
```

These tests are additional confidence, not part of the scripted product gate.

## Artifacts You Do Not Need To Remember Manually

If you use the wrapper scripts, you do not need to remember to create these by
hand:

- `build/FN-BOOT.ssd`
- `build/OTHER.ssd`

`./scripts/run_fn_boot_test.sh` creates them.
`./integration-tests/beebium/run_product_tests.sh` includes that script as its
final lane.

## Summary

Use these commands as the mental model:

- `./run_tests.sh` = repo-level local gate
- `./integration-tests/beebium/run_product_tests.sh` = complete Beebium scripted gate
- `./scripts/run_fn_boot_test.sh` = transient command / library-drive lane
- `cd integration-tests/beebium && ./run_pytest.sh scripted/...` = one scripted subset while iterating
