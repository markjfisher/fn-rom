# Test harness (fake MOS / OSBYTE)

When ROM code under test calls **`$FFF4`** (OSBYTE), the soft65c02 harness has no real BBC MOS.

This blob provides replacement stubs for the OS vectors.

## Build

From this directory:

```bash
./build.sh
```

Requires [cc65](https://cc65.github.io/) (`ca65` / `ld65`).

## Wire into `soft65c02_tester`

```text
memory load atari "/absolute/path/to/fn-rom/unit-tests/harness/build/harness.bin"
```

Optional: simulate CTRL for LED/OSBYTE &76 paths:

```text
memory write $osbyte76_fake_keyboard 0x80
```

## Extending

1. Add branches in `osbyte_entry` for other **`A`** values your ROM uses (serial, filing, etc.).
2. For each call, document **your** exit contract (AUG where it matters; otherwise pick stable Y/register behavior for tests).
