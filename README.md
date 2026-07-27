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

## Product build

fn-rom now has one product shape: disk + network device in ROM, with bulky
management/informational commands on the boot/config utilities disk. There is no
ALL/DISK/DISK+NET product matrix.

| Build | Target | For |
|-------|--------|-----|
| **FN-NET** | `make all` | BBC product ROM |
| **FN-NET-M** | `make all BUILD_MACHINE=MASTER` | BBC Master product ROM |

`make sizes` reports per-ROM segment usage and free bytes (build first).
The build remains orthogonal to `BUILD_MACHINE` (BBC|MASTER) and
`BUILD_INTERFACE` (SERIAL|USERPORT|1MHZ).

The resident ROM budget is reserved for functionality that cannot be delivered
from disk: filing-system vectors, FujiBus/SLIP/channel code, device protocols,
OSWORD contracts, bootstrap/recovery commands, and thin wrappers over resident
APIs such as `*FJSON`. Utility apps belong on the boot/config disk so future
device work has headroom on constrained BBC-class machines.

## Release bundle

`make release` (alias `make dist`) stages the shippable bundle in
`dist/release/`: the `FN-NET` / `FN-NET-M` ROM images, `FN-UTLS.ssd` (the
boot/config utilities disk), and the `bas/` example apps as ready-to-mount SSDs.
Choose which examples with `RELEASE_APPS="weather iss"`.

## Testing

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for Beebium test setup (two env vars).

A single command builds the product ROMs, reports sizes, and runs the unit +
Beebium scripted suites:
```
./run_tests.sh                # full matrix (add --no-beebium for builds-only)
./run_unit_tests.sh           # soft65c02 unit tests
```
The Beebium runner (`integration-tests/beebium/run_product_tests.sh`) runs the
product scripted suite plus the FN-UTLS command-from-disk tests. Tests that need
FN-UTLS mounted as the library use the `needs_boot_utils_setup` marker and are
covered by that command-from-disk lane. See
`integration-tests/beebium/README.md`. Day-to-day Beebium commands:
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
