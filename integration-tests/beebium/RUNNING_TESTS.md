# Running The Beebium Tests

This guide is the short, practical companion to `README.md`.

Use this file when you want to know:

- what command to run
- which ROM profile it uses
- which skips are expected
- when coverage is complete

**Setup:** export `BEEBIUM_HOME` and `FUJINET_NIO_HOME`, then run tests. See
[docs/DEVELOPMENT.md](../../docs/DEVELOPMENT.md). Use `./run_pytest.sh` (not bare
`uv run pytest`).

## Short Answer

If you want confidence that the Beebium scripted coverage is complete, run:

```bash
./integration-tests/beebium/run_profile_tests.sh
```

If you want the repository's normal full local gate, run:

```bash
./run_tests.sh
```

Coverage is complete when all four Beebium lanes pass:

1. `all` profile scripted tests
2. `net` profile scripted tests
3. `disk` profile scripted tests
4. `FN-UTLS` command-from-disk lane

The skip counts in the first three lanes are expected. They are how one shared
suite expresses profile-specific coverage.

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

### 2. Beebium scripted matrix only

This is the main command for the Beebium matrix.

```bash
./integration-tests/beebium/run_profile_tests.sh
```

This runs four lanes in sequence:

1. `all`: ALL ROM (`FEATURE_NET=1`, `UTILITIES=resident`)
2. `net`: DISK+NET ROM (`FEATURE_NET=1`, `UTILITIES=disk`)
3. `disk`: DISK ROM (`FEATURE_NET=0`, `UTILITIES=disk`)
4. `utls`: rebuild transient utility artifacts and run `test_command_from_disk.py`

The fourth lane is important. It is the lane that creates `build/FN-UTLS.ssd`
and `build/OTHER.ssd` and proves the transient-command-on-disk behavior.

### 3. One profile only

Useful while iterating on a specific profile.

Build the ROM first, then run the scripted suite with the matching profile:

```bash
make all-rom
cd integration-tests/beebium
FN_PROFILE=all ./run_pytest.sh scripted/ -q
```

```bash
make net
cd integration-tests/beebium
FN_PROFILE=net ./run_pytest.sh scripted/ -q
```

```bash
make disk
cd integration-tests/beebium
FN_PROFILE=disk ./run_pytest.sh scripted/ -q
```

### 4. Transient command / FN-UTLS lane only

Use this when changing disk-loaded utility behavior such as `*FLS`, `*FDRIVE`,
`*FCD`, library-drive fallback, or argument passing.

```bash
./scripts/run_fn_utls_test.sh
```

This script:

1. builds the `UTILITIES=disk` ROM
2. rebuilds `build/FN-UTLS.ssd`
3. rebuilds `build/OTHER.ssd`
4. runs `integration-tests/beebium/scripted/test_command_from_disk.py`

If you need just one command-from-disk test after the assets exist:

```bash
cd integration-tests/beebium
FN_UTLS_TEST=1 FN_PROFILE=net FN_ROM=../../build/fujinet.rom \
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

Supported today:

- `01_osfile.yaml`
- `02_osargs.yaml`
- `04_ctests.yaml` in the `all` profile, because it needs resident utilities

The runner deliberately supports only the YAML features used by those migrated
suites: top-level `disk`/`paste`, step `paste`, step `delay_seconds`, and screen
checks with `contains` or `regex`. Service-backed suites such as the old open,
long-string, and JSON tests still need a small service-host templating layer
before they can be made deterministic under Beebium.

## Why The Skips Are Expected

The same scripted suite is reused across multiple shipped ROM profiles.
Markers describe which features a test requires, and pytest skips the tests that
cannot apply to the currently loaded ROM.

### Marker meanings

| Marker | Runs on | Skips on | Why |
|--------|---------|----------|-----|
| `needs_net` | `all`, `net` | `disk` | the DISK profile has no network device |
| `needs_resident_utils` | `all` | `net`, `disk` | utility is resident only in `all`; in `net`/`disk` it is transient on `FN-UTLS.ssd` |
| `disk_only` | `disk` | `all`, `net` | checks behavior specific to the no-network DISK build |

### Meaning of each lane

| Lane | What it proves | Expected skips |
|------|----------------|----------------|
| `all` | resident utility commands, network paths, normal scripted transport coverage | `disk_only` tests skip |
| `net` | network profile with utilities on disk; network paths still work when utils are not resident | `needs_resident_utils` and `disk_only` tests skip |
| `disk` | no-network profile behavior and disk-only assertions | `needs_net` and `needs_resident_utils` tests skip |
| `utls` | transient command loading from `FN-UTLS.ssd`, including library fallback and argument passing | no profile-marker skips; this is its own targeted lane |

So the presence of skips does not mean coverage is missing. It means coverage is
split across lanes.

## How To Know Coverage Is Complete

For the Beebium scripted layer, coverage is complete when these all pass:

1. `all` scripted lane
2. `net` scripted lane
3. `disk` scripted lane
4. `utls` command-from-disk lane

That is exactly what `run_profile_tests.sh` is intended to represent.

The first three lanes cover profile-gated ROM behavior.
The fourth lane covers transient utilities that are deliberately absent from the
`net` and `disk` ROM images.

If only the first three lanes run, coverage is not complete for transient utils.
If only the `utls` lane runs, coverage is not complete for resident-utils or
profile-gated behavior.

## Recommended Workflows

### Fast local iteration on one area

Network feature change:

```bash
make net
cd integration-tests/beebium
FN_PROFILE=net ./run_pytest.sh scripted/test_network_device.py -q
```

Disk-only change:

```bash
make disk
cd integration-tests/beebium
FN_PROFILE=disk ./run_pytest.sh scripted/test_disk_profile.py -q
```

Resident utility change:

```bash
make all-rom
cd integration-tests/beebium
FN_PROFILE=all ./run_pytest.sh scripted/ -q -k fls
```

Transient utility change:

```bash
./scripts/run_fn_utls_test.sh -k fls
```

### Before committing

Run the Beebium scripted matrix:

```bash
./integration-tests/beebium/run_profile_tests.sh
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

These tests are additional confidence, not part of the scripted profile matrix.

## Artifacts You Do Not Need To Remember Manually

If you use the wrapper scripts, you do not need to remember to create these by
hand:

- `build/FN-UTLS.ssd`
- `build/OTHER.ssd`

`./scripts/run_fn_utls_test.sh` creates them.
`./integration-tests/beebium/run_profile_tests.sh` includes that script as its
final lane.

## Summary

Use these commands as the mental model:

- `./run_tests.sh` = repo-level local gate
- `./integration-tests/beebium/run_profile_tests.sh` = complete Beebium scripted matrix
- `./scripts/run_fn_utls_test.sh` = transient command / library-drive lane
- `FN_PROFILE=<profile> ./run_pytest.sh scripted/...` = one profile while iterating
