# fn-rom

A bbc ROM for fujinet.

Using cc65.

It is extensively based on mmfs as an example of how to build a rom.

**New developer?** See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build tools,
Beebium integration tests, and environment variables.

# What it should do minimally

- interfaces to the FN to support file system
- and network, and other devices

# Things it will do eventually

- use multiple buses (first will be rs232)
- support more than bbc (i.e. master, elk)

# Building

This will build the ROM in build/
```
make clean all
```

This will create an SSD containing the ROM
```
make clean ssd
```

## Build profiles (role split)

fn-rom is built in one of three role-split *profiles*, selected by two
orthogonal levers (see [docs/ROM_ROLE_SPLIT_PLAN.md](docs/ROM_ROLE_SPLIT_PLAN.md)):

- `FEATURE_NET` (Lever A) — `1` adds the network device (OPENIN `"scheme://"`,
  `*FJSON`, the OSWORD &78 API); `0` is disk-only. Disk is always resident.
- `UTILITIES` (Lever B) — `resident` links the management/informational commands
  (`*FORM`, `*COPY`, `*FLS`, `*FDRIVE`, …) into the ROM; `disk` drops them, so
  they ship on `FN-UTLS.ssd` and load on demand via the MOS unrecognised-command
  → `*RUN` fallthrough.

| Profile | Target | FEATURE_NET | UTILITIES | For |
|---------|--------|:-----------:|:---------:|-----|
| **ALL**      | `make all-rom` (== bare `make all`) | 1 | resident | everything resident, kitchen-sink |
| **DISK+NET** | `make net`     | 1 | disk     | default shipped build (network + disk) |
| **DISK**     | `make disk`    | 0 | disk     | disk-only |

`make sizes` reports per-ROM segment usage and free bytes (build first).
Profiles are orthogonal to `BUILD_MACHINE` (BBC|MASTER) and `BUILD_INTERFACE`
(SERIAL|USERPORT|1MHZ).

## Release bundle

`make release` (alias `make dist`) stages the shippable **DISK+NET** bundle in
`dist/release/`: the `FN-NET` / `FN-NET-M` ROM images, `FN-UTLS.ssd` (the
transient utilities), and the `bas/` example apps as ready-to-mount SSDs. Choose
which examples with `RELEASE_APPS="weather iss"`.

## Testing

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for Beebium test setup (two env vars).

A single command builds every profile, reports sizes, and runs the unit +
beebium scripted suites for each:
```
./run_tests.sh                # full matrix (add --no-beebium for builds-only)
./run_unit_tests.sh [all|net|disk]   # soft65c02 unit tests for one profile
```
The beebium matrix (`integration-tests/beebium/run_profile_tests.sh`) runs the
scripted suite against the `all`, `net` and `disk` ROMs plus the FN-UTLS
command-from-disk equivalence test. Tests declare the feature they need
(`needs_net`, `needs_resident_utils`, `disk_only`) and are skipped on profiles
that don't provide it. See [docs/ROM_ROLE_SPLIT_PLAN.md](docs/ROM_ROLE_SPLIT_PLAN.md)
Appendix C and `integration-tests/beebium/README.md`. Day-to-day Beebium commands:
[integration-tests/beebium/RUNNING_TESTS.md](integration-tests/beebium/RUNNING_TESTS.md).

# Creating SSD images from folder contents

The script [create_ssd.py](scripts/create_ssd.py) can be used to make SSD images from a folder's contents.

For binary files (not having extension ".bas"), it will store them directly on the disk, and set a load/execute
address according to the parameters passed to the script. There is a limitation that all applications will share the same
load and exec address currently.

For BASIC files, it will tokenize and add line numbers as required to the source file. See below.

You need [basictool](https://github.com/ZornsLemma/basictool) and [dfstool](https://github.com/rcook/dfstool) installed locally.

An example to create the "net" example basic files into "net.ssd" is:

```bash
scripts/create_ssd.py -i bas/net -o net.ssd
```

See the help for the script with `scripts/create_ssd.py -h`

## Converting BAS files

Basic files do not need line numbers, the basictool can deal with that automatically.
If you need GOTO statements, then the target line will need a line number, and basictool will automatically
adjust other line numbers around that point.

One convention used by the script is that if the first line of the program is of the format:
```
REM filename: foo
```
then the file will be stored on the disk as "FOO", instead of the name of the source file.
This allows you to have normal file names on a modern system but tokenize them to a short name for the SSD image.

## Mount policy

- `*FIN` persists the slot URI and currently stores default slot policy `auto`
- `*FMOUNT` owns the live mount mode
- `*FMOUNT <slot> [drive]` uses `auto`: try writable, fall back to read-only if needed
- `*FMOUNT <slot> [drive] RO` forces a read-only live mount
- If the live mount falls back to read-only, the ROM prints `Mounted read-only`
