# Test harness (fake MOS / OSBYTE)

When ROM code under test calls (e.g.) **`$FFF4`** (OSBYTE), the soft65c02 harness has no real BBC MOS.

This blob provides replacement stubs for the OS vectors.

## Test RAM (not in the harness binary)

`harness.ld65.cfg` reserves `$C800`–`$CFFF` with `file=""` so **no mock data is linked into the harness `.atari` file**. Each test script owns that RAM:

```
memory fill #0xC800~#0xCFFF   $$ clear $$
memory load #0xC800 "${UNIT_TEST_DIR}/data/....bin"
```

Use different load addresses per test (e.g. SLIP replay at `$C000`, print capture at `$C800`) so multiple captures can be exercised in one session.

## Serial mock (FujiBus / RS423)

`serial_mock.s` replays SLIP packets from an address in test RAM (default base `$C000` via `mock_slip_base`):

1. `memory load #0xC000 "${UNIT_TEST_DIR}/data/fls/....bin"`
2. `memory write $mock_slip_len <lo> <hi>` (file size)
3. `run $mock_slip_rewind` before each command under test

## Print capture

`print_mock.s` stores OSWRCH output at **`$C800`** when `mock_print_armed` is non-zero. Tests clear `$C800`–`$CFFF`, arm capture at the right point (e.g. when `PC = $cfl_entry_loop`), then assert on `#0xC800`.

`gs_stub.s` reads the simulated command line from **`$C900`** (NUL-terminated; GSREAD ends with CR). This is in the harness's dedicated mock-data region and cannot overlap the linked test program.

## Build

The unit tester `soft65c02_unit` builds the harness when running a test. Requires `fnrom.inc` in this folder (`./create_rom_inc.sh` from the repo root, or `./run_unit_tests.sh`).

Requires [cc65](https://cc65.github.io/) (`ca65` / `ld65`).
